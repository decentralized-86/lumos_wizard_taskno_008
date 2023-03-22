//Enter the Lottery (paying some amount)
//Pick a random winner -> (Verifiable random)(automatically done)
//Winner To Be selected Every X minutes
//ChainLink Oracles -> Randomnes Automated Execution (ChainLink Keeper)

//SPDX-License-Identifier:MIT

pragma solidity ^0.8.9;
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

/*  ERRORS  */
error Lottery__SendMoreToEnter();
error Lottery__TransactionFailed();
error Lottery__RaffleNotOpen();
error Lottery__UpKeepNotNeeded();

contract Lottery is VRFConsumerBaseV2, KeeperCompatibleInterface {
    /*  TYPES */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /*  @state variables    */
    /*  ChainLink VRF Variables */
    VRFCoordinatorV2Interface private immutable i_Vrf_Coordinator;
    bytes32 private immutable i_keyHash;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable public s_recent_Winner;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_RANDOM_WORDS = 1;

    /*  LOTTERY STATE VARIABLES */
    uint256 private immutable i_interval;
    uint256 private immutable i_EntryFee;
    uint256 private s_LastTimeStamp;
    address payable[] public s_players;
    RaffleState private s_rafflestate;

    /*  Events  */
    event LotteryEnter(address indexed Player);
    event RequestedRafflewinner(uint256 indexed requestId);
    event Recent_winner(address indexed winner);

    constructor(
        address vrfcoordinatorV2,
        uint256 entryFee,
        bytes32 keyHash,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2(vrfcoordinatorV2) {
        i_EntryFee = entryFee;
        i_Vrf_Coordinator = VRFCoordinatorV2Interface(vrfcoordinatorV2);
        i_keyHash = keyHash;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_rafflestate = RaffleState.OPEN;
        i_interval = interval;
        s_LastTimeStamp = block.timestamp;
    }

    /*  Enter the Lotery with this function */
    function EnterLottery() public payable {
        // if the raffle state is not open you wont be able to take part
        if (s_rafflestate != RaffleState.OPEN) revert Lottery__RaffleNotOpen();
        // If the amount is less than the EntryFee You wont be able to participate
        if (msg.value < i_EntryFee) revert Lottery__SendMoreToEnter();
        //put the address in the players array to allow to be part of the Lottery
        s_players.push(payable(msg.sender));
        // Emit the participant Every time a new address come for the Lottery
        emit LotteryEnter(msg.sender);
    }

    /**
     * @dev this is the function that the chainlink keeper nodes call
     * they look for the upkeep needed to return true
     * the following should be true in order to return true
     * 1. out time interval should have passed
     * 2. lottery should have selected one winner and have some ETH
     * 3. our Subscription should have funded with LINK token
     * 4. The lottery should be in "open" state
     */
    function checkUpkeep(
        bytes memory /* checkData*/
    )
        public
        override
        returns (
            bool upkeepNeeded,
            bytes memory /* Perform_DATA */
        )
    {
        bool isopen = (RaffleState.OPEN == s_rafflestate);
        bool timepassed = ((block.timestamp - s_LastTimeStamp) > i_interval);
        bool has_players = (s_players.length > 0);
        bool hasbalance = address(this).balance > 0;
        upkeepNeeded = (timepassed && has_players && isopen && hasbalance);
        return (upkeepNeeded, "0x");
    }

    /*  Request the Random Winner   */
    function performUpkeep(
        bytes calldata /* Perform Data */
    ) external override {
        // Request a random number
        // Once you get it Do something with it
        // Two way transaction
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) revert Lottery__UpKeepNotNeeded();
        s_rafflestate = RaffleState.CALCULATING;
        uint256 Request_id = i_Vrf_Coordinator.requestRandomWords(
            i_keyHash,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_RANDOM_WORDS
        );
        emit RequestedRafflewinner(Request_id);
    }

    /*  Full Fill The Random Words   */
    function fulfillRandomWords(
        uint256, /*requestId*/
        uint256[] memory randomWords
    ) internal override {
        uint256 index_of_winner = randomWords[0] % s_players.length;
        address payable recent_Winner = s_players[index_of_winner];
        s_recent_Winner = recent_Winner;
        s_rafflestate = RaffleState.OPEN;
        s_LastTimeStamp = block.timestamp;
        s_players = new address payable[](0);
        (bool success, ) = s_recent_Winner.call{value: address(this).balance}(
            ""
        );
        if (!success) {
            revert Lottery__TransactionFailed();
        }
        emit Recent_winner(s_recent_Winner);
    }

    /*  View And Pure Functions    */
    function Get_s_players(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function Get_i_EntryFee() public view returns (uint256) {
        return i_EntryFee;
    }

    function Get_s_recent_Winner() public view returns (address) {
        return s_recent_Winner;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_rafflestate;
    }

    function GetNumWords() public pure returns (uint32) {
        return NUM_RANDOM_WORDS;
    }

    function GetNoOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function GetLatestTimeStamp() public view returns (uint256) {
        return s_LastTimeStamp;
    }

    function Get_NoOfRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function Get_interval() public view returns (uint256) {
        return i_interval;
    }
}
