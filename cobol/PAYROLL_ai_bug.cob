       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAYROLL.
       AUTHOR. ACME-BANK.
       DATE-WRITTEN. 2024-01-15.
      *----------------------------------------------------------------
      * ORIGINAL payroll calculation — pre-AI-modification baseline.
      * Used by Refinery formal verification demo.
      *
      * Z3 will compare this against demo_equiv.cob and demo_bug.cob.
      *----------------------------------------------------------------
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01  WS-BASE-PAY      PIC 9(7)V99  COMP-3 VALUE ZEROS.
       01  WS-BONUS         PIC 9(7)V99  COMP-3 VALUE ZEROS.
       01  WS-DEDUCTION     PIC 9(7)V99  COMP-3 VALUE ZEROS.
       01  WS-TAX-RATE      PIC 9(3)V99  COMP-3 VALUE ZEROS.
       01  WS-TAX-AMOUNT    PIC 9(7)V99  COMP-3 VALUE ZEROS.
       01  WS-NET-PAY       PIC 9(7)V99  COMP-3 VALUE ZEROS.

       PROCEDURE DIVISION.
      *----------------------------------------------------------------
       MAIN-LOGIC.
           MOVE 45000  TO WS-BASE-PAY
           MOVE 5000   TO WS-BONUS
           MOVE 8500   TO WS-DEDUCTION
           MOVE 20     TO WS-TAX-RATE
           PERFORM CALC-TAX
           PERFORM CALC-NET-PAY
           DISPLAY 'NET PAY: ' WS-NET-PAY
           STOP RUN.

      *----------------------------------------------------------------
       CALC-TAX.
           COMPUTE WS-TAX-AMOUNT = WS-BASE-PAY * WS-TAX-RATE.

      *----------------------------------------------------------------
       CALC-NET-PAY.
           COMPUTE WS-NET-PAY =
           WS-BASE-PAY + WS-BONUS * 2 - WS-DEDUCTION - WS-TAX-AMOUNT.

       END PROGRAM PAYROLL.
