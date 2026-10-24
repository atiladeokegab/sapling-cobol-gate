       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAYNET.
       AUTHOR. R-OKAFOR.
       DATE-WRITTEN. 2019-03-14.
      *----------------------------------------------------------------
      * Monthly net pay for salaried staff.
      * Overtime paid at time and a half; pension deducted before tax.
      *----------------------------------------------------------------
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01  WS-BASE-PAY        PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-OVERTIME-HRS    PIC 9(3)V99     COMP-3 VALUE ZEROS.
       01  WS-OVERTIME-RATE   PIC 9(3)V99     COMP-3 VALUE ZEROS.
       01  WS-PENSION-RATE    PIC 9(2)V99     COMP-3 VALUE ZEROS.
       01  WS-TAX-RATE        PIC 9(2)V99     COMP-3 VALUE ZEROS.
       01  WS-OVERTIME-PAY    PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-PENSION-AMT     PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-TAX-AMT         PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-NET-PAY         PIC 9(7)V99     COMP-3 VALUE ZEROS.

       PROCEDURE DIVISION.
      *----------------------------------------------------------------
       MAIN-LOGIC.
           MOVE 3850      TO WS-BASE-PAY
           MOVE 12.5      TO WS-OVERTIME-HRS
           MOVE 22.40     TO WS-OVERTIME-RATE
           MOVE 5         TO WS-PENSION-RATE
           MOVE 20        TO WS-TAX-RATE
           PERFORM CALC-OVERTIME
           PERFORM CALC-DEDUCTIONS
           PERFORM CALC-NET-PAY
           DISPLAY 'NET PAY: ' WS-NET-PAY
           STOP RUN.

      *----------------------------------------------------------------
       CALC-OVERTIME.
           COMPUTE WS-OVERTIME-PAY =
               WS-OVERTIME-HRS * WS-OVERTIME-RATE * 1.5.

      *----------------------------------------------------------------
       CALC-DEDUCTIONS.
           COMPUTE WS-PENSION-AMT =
               (WS-BASE-PAY + WS-OVERTIME-PAY) * WS-PENSION-RATE / 100.
           COMPUTE WS-TAX-AMT =
               (WS-BASE-PAY + WS-OVERTIME-PAY - WS-PENSION-AMT)
               * WS-TAX-RATE / 100.

      *----------------------------------------------------------------
       CALC-NET-PAY.
           COMPUTE WS-NET-PAY =
               WS-BASE-PAY + WS-OVERTIME-PAY
               - (WS-PENSION-AMT + WS-TAX-AMT).

       END PROGRAM PAYNET.
