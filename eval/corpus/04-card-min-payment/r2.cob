       IDENTIFICATION DIVISION.
       PROGRAM-ID. CARDMINP.
       AUTHOR. CARDS-BILLING.
       DATE-WRITTEN. 2018-11-05.
      *----------------------------------------------------------------
      * Credit card minimum repayment.
      * Percentage of the balance excluding interest and fees, plus
      * this period's interest and fees.
      *----------------------------------------------------------------
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01  WS-STMT-BALANCE    PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-INTEREST-CHG    PIC 9(5)V99     COMP-3 VALUE ZEROS.
       01  WS-FEES-CHG        PIC 9(5)V99     COMP-3 VALUE ZEROS.
       01  WS-MIN-PCT         PIC 9(2)V99     COMP-3 VALUE ZEROS.
       01  WS-PRIN-PORTION    PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-MIN-PAYMENT     PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-REMAINING       PIC 9(7)V99     COMP-3 VALUE ZEROS.

       PROCEDURE DIVISION.
      *----------------------------------------------------------------
       MAIN-LOGIC.
           MOVE 2475.60   TO WS-STMT-BALANCE
           MOVE 38.12     TO WS-INTEREST-CHG
           MOVE 12        TO WS-FEES-CHG
           MOVE 1         TO WS-MIN-PCT
           PERFORM CALC-PRINCIPAL-PORTION
           PERFORM CALC-MIN-PAYMENT
           DISPLAY 'MINIMUM PAYMENT: ' WS-MIN-PAYMENT
           STOP RUN.

      *----------------------------------------------------------------
       CALC-PRINCIPAL-PORTION.
           COMPUTE WS-PRIN-PORTION =
               (WS-STMT-BALANCE - WS-INTEREST-CHG - WS-FEES-CHG)
               * WS-MIN-PCT / 100.

      *----------------------------------------------------------------
       CALC-MIN-PAYMENT.
           COMPUTE WS-MIN-PAYMENT =
               WS-INTEREST-CHG + WS-FEES-CHG + WS-PRIN-PORTION.
           COMPUTE WS-REMAINING =
               WS-STMT-BALANCE - WS-MIN-PAYMENT.

       END PROGRAM CARDMINP.
