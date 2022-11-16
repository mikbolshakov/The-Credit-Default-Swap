// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Credit {
    address debtIssuer;
    address debtSeller; 
    address insuranceSeller;

    uint debtAmount = 50 ether; // сумма кредита 
    uint monthlyDebtPayment = 12 ether; // сумма ежемесячного платежа по кредиту 
    uint monthlyDebt = 10 ether; // тело кредита ежемесячно 

    uint insuranceInterestAmount = 5 ether; // сумма процентов страховки 
    uint monthlyInsurancePayment = 11 ether; // сумма ежемесячного платежа за страховку 
    uint monthlyInsuranceInterest = 1 ether; // процент страховки ежемесячно 

    uint monthlyTimerForDebt; // дата крайнего платежа по кредиту
    uint monthlyTimerForInsurance; // дата крайнего платежа по страховке
    uint oneMonth = 60;

    mapping(address => bool) loanTaken;
    mapping(address => uint) public loanBalance;
    mapping(address => bool) monthlyLoanBalance;
    mapping(address => uint) public insuranceBalance;
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

    //                                          ДЕЙСТВИЯ ЗАЕМЩИКА debtIssuer
    // Забирает кредит 
    function takeDebt() public onlyDebtIssuer {
        require(debtAmount > 0, "no loans");
        require(loanTaken[debtIssuer], "you already take the loan");
        address payable _to = payable(msg.sender);
        _to.transfer(debtAmount);
        loanBalance[debtIssuer] = debtAmount;
        loanTaken[debtIssuer] = false;
        monthlyTimerForDebt = block.timestamp;
    }

    // Выплата ежемесячного платежа по кредиту
    function payDebtMonthlyPayment() public payable onlyDebtIssuer {
        address payable _to = payable(this);
        _to.transfer(monthlyDebtPayment);
        monthlyTimerForDebt = block.timestamp;
        require(loanBalance[debtIssuer] > 0, "you paid off the loan!");
        loanBalance[debtIssuer] -= monthlyDebt;
        monthlyLoanBalance[debtSeller] = true;
    }


    //                                          ДЕЙСТВИЯ КРЕДИТОРА debtSeller
    // Выдача суммы кредита 
    function debtIssuing() public payable onlyDebtSeller {
        address payable _to = payable(this);
        _to.transfer(debtAmount);
        loanTaken[debtIssuer] = true;
    }

    // Забирает ежемесячный платеж по кредиту
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

    // Выплата ежемесячного платежа за страхование 
    function payInsuranceMonthlyPayment() public payable onlyDebtSeller {
        address payable _to = payable(this);
        _to.transfer(monthlyInsurancePayment);
        monthlyTimerForInsurance = block.timestamp;
        insuranceBalance[debtSeller] -= monthlyInsuranceInterest;
        monthlyInsuranceBalance[debtSeller] = true;
    }


    //                                          ДЕЙСТВИЯ СТРАХОВЩИКА insuranceSeller
    // Выдача суммы покрытия страхования 
    function insuranceIssuing() public payable onlyInsuranceSeller {
        address payable _to = payable(this);
        _to.transfer(debtAmount);
        insuranceBalance[debtSeller] = insuranceInterestAmount;
        monthlyTimerForInsurance = block.timestamp;
    }

    // Забирает ежемесячный платеж по страхованию + сумму эквивалентную сумме выплаченного кредита
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
    
    // Сценарий не оплаты страхования: insuranceSeller забирает страховую сумму 
    function noMoreInsurance() internal {
        require(insuranceBalance[debtSeller] > 0, "debt seller repaid the insurance");
        address payable _to = payable(msg.sender);
        _to.transfer(address(this).balance);
    }

    // Сценарий не оплаты кредита: debtSeller забирает страховую сумму
    function noMoreDebtPayments() internal {
        require(loanBalance[debtIssuer] > 0, "debt issuer repaid the loan");
        address payable _to = payable(msg.sender);
        _to.transfer(address(this).balance);
    }

    fallback() external payable {}

    receive() external payable {}
}