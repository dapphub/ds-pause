pragma solidity >=0.5.0 <0.6.0;

contract DSPause {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address guy) public auth { wards[guy] = 1; }
    function deny(address guy) public auth { wards[guy] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    struct Execution {
        address  guy;
        bytes    data;
        uint256  timestamp;
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
        require(guy != address(0));

        id = keccak256(abi.encode(guy, data, now));

        Execution storage entry = queue[id];
        entry.guy = guy;
        entry.data = data;
        entry.timestamp = now;

        return id;
    }

    function cancel(bytes32 id) public auth {
        require(now > freezeUntil);
        delete queue[id];
    }

    function execute(bytes32 id) public payable returns (bytes memory response) {
        require(now > freezeUntil);

        Execution memory entry = queue[id];
        require(now > entry.timestamp + delay);

        require(entry.guy != address(0));
        delete queue[id];

        address target = entry.guy;
        bytes memory data = entry.data;

        // call contract in current context
        assembly {
            let succeeded := delegatecall(sub(gas, 5000), target, add(data, 0x20), mload(data), 0, 0)
            let size := returndatasize

            response := mload(0x40)
            mstore(0x40, add(response, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            mstore(response, size)
            returndatacopy(add(response, 0x20), 0, size)

            switch iszero(succeeded)
            case 1 {
                // throw if delegatecall failed
                revert(add(response, 0x20), size)
            }
        }
    }

    function freeze(uint timestamp) public auth {
        freezeUntil = timestamp;
    }
}
