// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Auto-Will Executor Smart Contract
 * @dev A decentralized system for automatic execution of digital wills
 * @author Auto-Will Team
 */
contract Project {
    
    struct Will {
        address testator;           // Person creating the will
        address[] beneficiaries;    // List of beneficiaries
        uint256[] amounts;          // Corresponding amounts for each beneficiary
        uint256 executionTime;      // When the will should be executed
        bool isExecuted;           // Execution status
        bool isActive;             // Will status
        uint256 totalAmount;       // Total amount in the will
    }
    
    mapping(address => Will) public wills;
    mapping(address => bool) public hasWill;
    
    event WillCreated(address indexed testator, uint256 totalAmount, uint256 executionTime);
    event WillExecuted(address indexed testator, uint256 totalAmount);
    event WillUpdated(address indexed testator, uint256 newExecutionTime);
    
    modifier onlyTestator() {
        require(hasWill[msg.sender], "No will found for this address");
        require(wills[msg.sender].testator == msg.sender, "Not authorized");
        _;
    }
    
    modifier willNotExecuted() {
        require(!wills[msg.sender].isExecuted, "Will already executed");
        _;
    }
    
    /**
     * @dev Creates a new will with beneficiaries and execution conditions
     * @param _beneficiaries Array of beneficiary addresses
     * @param _amounts Array of amounts corresponding to each beneficiary
     * @param _executionTime Unix timestamp when the will should be executable
     */
    function createWill(
        address[] memory _beneficiaries,
        uint256[] memory _amounts,
        uint256 _executionTime
    ) external payable {
        require(_beneficiaries.length > 0, "Must have at least one beneficiary");
        require(_beneficiaries.length == _amounts.length, "Beneficiaries and amounts length mismatch");
        require(_executionTime > block.timestamp, "Execution time must be in the future");
        require(msg.value > 0, "Must send some Ether with the will");
        require(!hasWill[msg.sender], "Will already exists for this address");
        
        uint256 totalAmounts = 0;
        for (uint256 i = 0; i < _amounts.length; i++) {
            require(_amounts[i] > 0, "Amount must be greater than 0");
            require(_beneficiaries[i] != address(0), "Invalid beneficiary address");
            totalAmounts += _amounts[i];
        }
        
        require(msg.value >= totalAmounts, "Insufficient funds for specified amounts");
        
        wills[msg.sender] = Will({
            testator: msg.sender,
            beneficiaries: _beneficiaries,
            amounts: _amounts,
            executionTime: _executionTime,
            isExecuted: false,
            isActive: true,
            totalAmount: msg.value
        });
        
        hasWill[msg.sender] = true;
        
        emit WillCreated(msg.sender, msg.value, _executionTime);
    }
    
    /**
     * @dev Executes the will if conditions are met (time has passed)
     * @param _testator Address of the person whose will to execute
     */
    function executeWill(address _testator) external {
        require(hasWill[_testator], "No will found for this address");
        Will storage will = wills[_testator];
        require(will.isActive, "Will is not active");
        require(!will.isExecuted, "Will already executed");
        require(block.timestamp >= will.executionTime, "Execution time not reached");
        
        will.isExecuted = true;
        will.isActive = false;
        
        // Transfer funds to beneficiaries
        for (uint256 i = 0; i < will.beneficiaries.length; i++) {
            payable(will.beneficiaries[i]).transfer(will.amounts[i]);
        }
        
        // Return any remaining balance to testator (in case of excess)
        uint256 totalDistributed = 0;
        for (uint256 i = 0; i < will.amounts.length; i++) {
            totalDistributed += will.amounts[i];
        }
        
        if (will.totalAmount > totalDistributed) {
            payable(will.testator).transfer(will.totalAmount - totalDistributed);
        }
        
        emit WillExecuted(_testator, will.totalAmount);
    }
    
    /**
     * @dev Updates the execution time of an existing will
     * @param _newExecutionTime New execution timestamp
     */
    function updateExecutionTime(uint256 _newExecutionTime) external onlyTestator willNotExecuted {
        require(_newExecutionTime > block.timestamp, "New execution time must be in the future");
        
        wills[msg.sender].executionTime = _newExecutionTime;
        
        emit WillUpdated(msg.sender, _newExecutionTime);
    }
    
  
    function getWillDetails(address _testator) external view returns (
        address[] memory beneficiaries,
        uint256[] memory amounts,
        uint256 executionTime,
        bool isExecuted,
        bool isActive,
        uint256 totalAmount
    ) {
        require(hasWill[_testator], "No will found for this address");
        Will memory will = wills[_testator];
        return (
            will.beneficiaries,
            will.amounts,
            will.executionTime,
            will.isExecuted,
            will.isActive,
            will.totalAmount
        );
    }
    
    /**
     * @dev Check if a will is ready for execution
     * @param _testator Address of the testator
     * @return Boolean indicating if will can be executed
     */
    function canExecuteWill(address _testator) external view returns (bool) {
        if (!hasWill[_testator]) return false;
        Will memory will = wills[_testator];
        return (will.isActive && !will.isExecuted && block.timestamp >= will.executionTime);
    }
    
    // Emergency function to deactivate will (only by testator)
    function deactivateWill() external onlyTestator willNotExecuted {
        wills[msg.sender].isActive = false;
        
        // Refund the testator
        payable(msg.sender).transfer(wills[msg.sender].totalAmount);
    }
}
