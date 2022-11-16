// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Credit {
    address debtIssuer;
    address debtSeller; 
    address insuranceSeller;

    uint debtAmount = 50 ether; // loan amount
    uint monthlyDebtPayment = 12 ether; // monthly loan payment amount
    uint monthlyDebt = 10 ether; // monthly loan body (without interest)

    uint insuranceInterestAmount = 5 ether; // insurance interest amount 
    uint monthlyInsurancePayment = 11 ether; // monthly insurance payment amount
    uint monthlyInsuranceInterest = 1 ether; // monthly insurance interest

    uint monthlyTimerForDebt; // timestamp of last monthly loan payment
    uint monthlyTimerForInsurance; // timestamp of last monthly insurance payment
    uint oneMonth = 60;

    mapping(address => bool) loanTaken;
    mapping(address => uint) public loanBalance; // loan balance
    mapping(address => bool) monthlyLoanBalance;
    mapping(address => uint) public insuranceBalance; // balance of insurance debt
    mapping(address => bool) monthlyInsuranceBalance;

    constructor(address _debtIssuer, address _debtSeller, address _insuranceSeller) {
        debtIssuer = _debtIssuer;
        debtSeller = _debtSeller;
        insuranceSeller = _insuranceSeller;
    }

    modifier onlyDebtIssuer() {
        require(msg.sender == debtIssuer, "you are not a debt issuer");
        _;
    }

    modifier onlyDebtSeller() {
        require(msg.sender == debtSeller, "you are not a debt seller");
        _;
    }

    modifier onlyInsuranceSeller() {
        require(msg.sender == insuranceSeller, "you are not a insurance seller");
        _;
    }

    /** ACTIONS OF THE DEBT ISSUER **/
    // Takes out a loan
    function takeDebt() public onlyDebtIssuer {
        require(debtAmount > 0, "no loans");
        require(loanTaken[debtIssuer], "you already take the loan");
        address payable _to = payable(msg.sender);
        _to.transfer(debtAmount);
        loanBalance[debtIssuer] = debtAmount;
        loanTaken[debtIssuer] = false;
        monthlyTimerForDebt = block.timestamp;
    }

    // Pays monthly loan payment
    function payDebtMonthlyPayment() public payable onlyDebtIssuer {
        address payable _to = payable(this);
        _to.transfer(monthlyDebtPayment);
        monthlyTimerForDebt = block.timestamp;
        require(loanBalance[debtIssuer] > 0, "you paid off the loan!");
        loanBalance[debtIssuer] -= monthlyDebt;
        monthlyLoanBalance[debtSeller] = true;
    }


    /** ACTIONS OF THE DEBT SELLER **/
    // Issuance of the loan amount
    function debtIssuing() public payable onlyDebtSeller {
        address payable _to = payable(this);
        _to.transfer(debtAmount);
        loanTaken[debtIssuer] = true;
    }

    // Takes monthly loan payment
    function takeDebtMonthlyPayment() public onlyDebtSeller {
        if(block.timestamp <= monthlyTimerForDebt + oneMonth) {
            require(monthlyLoanBalance[debtSeller], "monthly payment not paid");
            address payable _to = payable(msg.sender);
            _to.transfer(monthlyDebtPayment);
            monthlyLoanBalance[debtSeller] = false;
        } else {
            noMoreDebtPayments();
        }
    }

    // Pays monthly insurance payment
    function payInsuranceMonthlyPayment() public payable onlyDebtSeller {
        address payable _to = payable(this);
        _to.transfer(monthlyInsurancePayment);
        monthlyTimerForInsurance = block.timestamp;
        insuranceBalance[debtSeller] -= monthlyInsuranceInterest;
        monthlyInsuranceBalance[debtSeller] = true;
    }


    /** ACTIONS OF THE INSURANCE SELLER **/
    // Issuance of insurance coverage amount
    function insuranceIssuing() public payable onlyInsuranceSeller {
        address payable _to = payable(this);
        _to.transfer(debtAmount);
        insuranceBalance[debtSeller] = insuranceInterestAmount;
        monthlyTimerForInsurance = block.timestamp;
    }

    // Takes the monthly insurance payment + 
    // + the amount equivalent to the amount of the paid loan
    function takeInsuranceMonthlyPayment() public onlyInsuranceSeller {
        if(block.timestamp <= monthlyTimerForInsurance + oneMonth) {
            require(monthlyInsuranceBalance[debtSeller], "monthly payment not paid");
            address payable _to = payable(msg.sender);
            _to.transfer(monthlyInsurancePayment);
            monthlyInsuranceBalance[debtSeller] = false;
        } else {
            noMoreInsurance();
        }
    }
    
    // The debt seller doesn't pay insurance script: insurance seller takes the insurance amount
    function noMoreInsurance() internal {
        require(insuranceBalance[debtSeller] > 0, "debt seller repaid the insurance");
        address payable _to = payable(msg.sender);
        _to.transfer(address(this).balance);
    }

    // The debt issuer doesn't pay loan script: debt seller takes the insurance amount
    function noMoreDebtPayments() internal {
        require(loanBalance[debtIssuer] > 0, "debt issuer repaid the loan");
        address payable _to = payable(msg.sender);
        _to.transfer(address(this).balance);
    }

    fallback() external payable {}

    receive() external payable {}
}