       IDENTIFICATION DIVISION.
       PROGRAM-ID. SAVINT.
       AUTHOR. RETAIL-DEPOSITS.
       DATE-WRITTEN. 2012-02-08.
      *----------------------------------------------------------------
      * Savings interest for the period, including loyalty bonus.
      * Basic rate tax withheld on the combined interest.
      *----------------------------------------------------------------
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01  WS-AVG-BALANCE     PIC 9(9)V99     COMP-3 VALUE ZEROS.
       01  WS-GROSS-RATE      PIC 9(2)V99     COMP-3 VALUE ZEROS.
       01  WS-BONUS-RATE      PIC 9(2)V99     COMP-3 VALUE ZEROS.
       01  WS-DAYS-HELD       PIC 9(3)        COMP-3 VALUE ZEROS.
       01  WS-GROSS-INT       PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-BONUS-INT       PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-TAX-WITHHELD    PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-NET-INT         PIC 9(7)V99     COMP-3 VALUE ZEROS.

       PROCEDURE DIVISION.
      *----------------------------------------------------------------
       MAIN-LOGIC.
           MOVE 18500     TO WS-AVG-BALANCE
           MOVE 4.15      TO WS-GROSS-RATE
           MOVE 0.50      TO WS-BONUS-RATE
           MOVE 92        TO WS-DAYS-HELD
           PERFORM CALC-GROSS-INTEREST
           PERFORM CALC-NET-INTEREST
           DISPLAY 'NET INTEREST: ' WS-NET-INT
           STOP RUN.

      *----------------------------------------------------------------
       CALC-GROSS-INTEREST.
           COMPUTE WS-GROSS-INT =
               WS-AVG-BALANCE * WS-GROSS-RATE / 100
               * WS-DAYS-HELD / 365.
           COMPUTE WS-BONUS-INT =
               WS-AVG-BALANCE * WS-BONUS-RATE / 100
               * WS-DAYS-HELD / 365.

      *----------------------------------------------------------------
       CALC-NET-INTEREST.
           COMPUTE WS-TAX-WITHHELD =
               (WS-GROSS-INT + WS-BONUS-INT) * 0.40.
           COMPUTE WS-NET-INT =
               WS-GROSS-INT + WS-BONUS-INT - WS-TAX-WITHHELD.

       END PROGRAM SAVINT.
