    //SPDX-License-Identifier: MIT
    pragma solidity ^0.8.9;


    contract loan {

        // we introduce every step which would be required in a conventional debt issue
        // on par value and interest rate
        uint private interestRate;
        uint public depositAmount;  //which resembles the face value
        uint public interestAmount; //which resembles the periodic interest amount
    

        // we need a point in time where the interest gets payed and where the debt gets payed back
        uint private maturity; //how long is the debt contract? usually we assume years but for visualization we will have maturity in hours
        uint private finalPaymentDue; //when is the final payment due
        uint private nextPaymentDue;
        uint private numberOfPayments; //just to see the number of payments left

        // we need something to trigger an event later (i.e. if no payment that would be true)
        uint public payedInterest;
        bool public paymentDefault;

        // We also need two agents 
        address private immutable debtLender;
        address private immutable debtBorrower;

        // Events
        event interestDefault(address indexed eventUser, uint indexed eventAmount, uint indexed eventTime); // index so we can look for it later
        

        // for insurance part
        address private immutable insuranceSeller;
        uint public requiredInsurancePayment; 
        uint private payedInsurance;
        uint private insuranceDefaultDeposit; 
        bool public insuranceCovered;

        //receive() external payable {}

        //Of course some of the values have to be decided before deploying the contract
        //Since Borrower and Lender have to agree on maturity and interestrate, we decide it at deployment

        constructor (address _debtLender, address _debtBorrower, address _insuranceSeller, uint _interestRate, uint _maturity) { // uint _parValue,  
            debtLender = _debtLender;
            debtBorrower = _debtBorrower;
            interestRate = _interestRate;
            maturity = _maturity;
            numberOfPayments = _maturity * 12; // How many payments (we assume maturity = 1 hour for the project)
            finalPaymentDue = block.timestamp + numberOfPayments * 3 minutes + 5 minutes; //final payment in X, we assume that we get a payment every 10 mins
            
            insuranceSeller = _insuranceSeller;
            }




        // DEBT ISSUE OF LENDER AND TRANSFER TO BORROWER

        function debt_issue() public payable returns(uint) {  
            require (msg.sender == debtLender, "Address has to be the debt lender");                    
            //require (msg.value > 0);
            depositAmount += msg.value;
            interestAmount = interestRate*depositAmount/100;

            requiredInsurancePayment = interestAmount * 2;

            require (address(this).balance > 0, "The balance of this contract is 0, i.e. the loan was not deposited yet");
            (bool success, ) = debtBorrower.call{value: address(this).balance}("");
            require(success, "Failed to transfer loan to borrower");
            nextPaymentDue = block.timestamp + 2 minutes;
            return nextPaymentDue;
        }

        // From this function/point of time, the "clock ticks"!

        // PAYMENT OF INSURANCE PREMIUM BY LENDER AND TRANSFER TO INSURANCE SELLER

        function insurancePremiumPayment () public payable {
            require (msg.sender == debtLender, "Address has to be the debt lender");
            require (requiredInsurancePayment == msg.value, "Payment deviates from insurance premium required");               //so the interest is actually the required amount
                
            payedInsurance += msg.value;
            insuranceCovered = true;
                
            require (address(this).balance > 0, "The balance of the contract is 0, i.e. insurance premium wasnt payed");
            (bool success, ) = insuranceSeller.call{value: payedInsurance}("");
            require(success, "Failed to transfer insurance premium");
        }


        //Check the contract balance just incase
        function contract_balance () public view returns (uint) {
            return address(this).balance;
        }
        

    

        // INTEREST PAYMENT AND TRANSFER TO LENDER

        function periodic_interest_payment () public payable returns (bool, uint){
            
            //requirere statements

            if (nextPaymentDue > block.timestamp) {
                require (msg.sender == debtBorrower, "Address has to be the debt borrower");
                require (interestAmount == msg.value, "Payment deviates from interest amount required");                                              //so the interest is actually the required amount
                //require (nextPaymentDue > block.timestamp, "The interest wasnt payed on time: DEFAULT");
                require (numberOfPayments > 0, "All required coupons were payed already!");
                payedInterest += msg.value;
                numberOfPayments -= 1;
        
                emit interestDefault(msg.sender, msg.value, block.timestamp); //You could have a front-end web app to listen to the events using web3 API.
        
                nextPaymentDue = block.timestamp + 2 minutes;
        
                require (address(this).balance > 0, "The balance of the contract is 0, i.e. the periodic interest wasnt paid");
                (bool success, ) = debtLender.call{value: address(this).balance}("");
                require(success, "Failed to transfer interest");

            } else {
            paymentDefault = true;    
        
            }
          
            return (paymentDefault, nextPaymentDue);
        
        }
        

        //PAYBACK OF INITIAL LOAN AMOUNT

        function maturity_payback () public payable returns(bool) {
        
            //require statements

            if (finalPaymentDue > block.timestamp) {
                require (msg.sender == debtBorrower, "Address has to be the debt borrower");
                require (depositAmount == msg.value, "Payment deviates from required initial loan/parValue amount");  
                require (finalPaymentDue > block.timestamp, "The interest wasnt payed on time: DEFAULT!!");
                require (numberOfPayments == 0, "There is still Interest to pay!");
                depositAmount -= msg.value;

                require (address(this).balance > 0, "The balance of the contract is 0, i.e. the parValue wasnt paid back yet");
                (bool success, ) = debtLender.call{value: address(this).balance}("");
                require(success, "Failed to transfer parValue back");

            }
            else {
                paymentDefault = true;
            }

            return paymentDefault;
        }




        //AFTER DEFAULT -> PAY THE INSURED AMOUNT TO THE LENDER

        function defaultTrigger () public payable{
            require (paymentDefault == true, "The payment has not defaulted");
            require (msg.sender == insuranceSeller, "Only the insurance seller can make this payment");
            require (depositAmount > 0,"");
            require (depositAmount == msg.value, "The insurance seller will replace exactly the parValue");
            require (insuranceCovered == true, "The insurance wasnt covered, the lender didnt pay in the first place");

            insuranceDefaultDeposit += msg.value; // put the face value into the contract

            require (insuranceDefaultDeposit > 0, "YYY");
            (bool success, ) = debtLender.call{value: address(this).balance}(""); //clear the balance
            require(success, "XXX");

            insuranceCovered = false;
        }




    }



// 0x483a7B5eCbF6f3B17701440C3ebc497eBC6D846c
// 0xFe62c817c6aa68DbeadadEe32614dD37e6080754
// 0x8Ba3E0E741287AB1003dAf120b1Cdf0226a00f30