pragma solidity >=0.5.0 <0.6.0;

contract DSDelay {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address guy) public auth { wards[guy] = 1; }
    function deny(address guy) public auth { wards[guy] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    struct Execution {
        address  guy;
        bytes    data;
        uint     timestamp;
        bool     done;
    }

    mapping (bytes32 => Execution) public queue;
    uint public delay;
    uint public freezeUntil;

    // --- Init ---
    constructor(uint delay_) public {
        wards[msg.sender] = 1;
        delay = delay_;
        freezeUntil = 0;
    }

    // --- Logic ---
    function enqueue(address guy, bytes memory data) public auth returns (bytes32 id) {
        require(now > freezeUntil);
        id = keccak256(abi.encode(guy, data, now));

        Execution storage entry = queue[id];
        entry.guy = guy;
        entry.data = data;
        entry.timestamp = now;
        entry.done = false;

        return id;
    }

    function cancel(bytes32 id) public auth {
        require(now > freezeUntil);
        delete queue[id];
    }

    function execute(bytes32 id) public {
        Execution memory entry = queue[id];

        require(now > freezeUntil);
        require(now > entry.timestamp + delay);

        require(entry.done == false);
        entry.done = true;

        entry.guy.delegatecall(entry.data);
    }

    function freeze(uint timestamp) public auth {
        freezeUntil = timestamp;
    }
}
