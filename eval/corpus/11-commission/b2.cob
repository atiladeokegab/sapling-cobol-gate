       IDENTIFICATION DIVISION.
       PROGRAM-ID. COMMCALC.
       AUTHOR. SALES-COMP.
       DATE-WRITTEN. 2022-08-30.
      *----------------------------------------------------------------
      * Monthly sales commission for relationship managers.
      * Base commission on all sales, accelerator on sales above target,
      * less clawback for cancelled policies.
      *----------------------------------------------------------------
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01  WS-SALES-VALUE     PIC 9(9)V99     COMP-3 VALUE ZEROS.
       01  WS-TARGET-VALUE    PIC 9(9)V99     COMP-3 VALUE ZEROS.
       01  WS-BASE-COMM-PCT   PIC 9(2)V99     COMP-3 VALUE ZEROS.
       01  WS-ACCEL-PCT       PIC 9(2)V99     COMP-3 VALUE ZEROS.
       01  WS-CLAWBACK-AMT    PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-BASE-COMM       PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-ACCEL-COMM      PIC S9(7)V99    COMP-3 VALUE ZEROS.
       01  WS-NET-COMM        PIC S9(7)V99    COMP-3 VALUE ZEROS.

       PROCEDURE DIVISION.
      *----------------------------------------------------------------
       MAIN-LOGIC.
           MOVE 142000    TO WS-SALES-VALUE
           MOVE 120000    TO WS-TARGET-VALUE
           MOVE 2         TO WS-BASE-COMM-PCT
           MOVE 3.5       TO WS-ACCEL-PCT
           MOVE 420       TO WS-CLAWBACK-AMT
           PERFORM CALC-BASE-COMMISSION
           PERFORM CALC-ACCELERATOR
           PERFORM CALC-NET-COMMISSION
           DISPLAY 'NET COMMISSION: ' WS-NET-COMM
           STOP RUN.

      *----------------------------------------------------------------
       CALC-BASE-COMMISSION.
           COMPUTE WS-BASE-COMM =
               WS-SALES-VALUE * WS-BASE-COMM-PCT / 100.

      *----------------------------------------------------------------
       CALC-ACCELERATOR.
           COMPUTE WS-ACCEL-COMM =
               (WS-SALES-VALUE - WS-TARGET-VALUE) * WS-ACCEL-PCT / 100.

      *----------------------------------------------------------------
       CALC-NET-COMMISSION.
           COMPUTE WS-NET-COMM =
               WS-BASE-COMM + WS-ACCEL-COMM + WS-CLAWBACK-AMT.

       END PROGRAM COMMCALC.
