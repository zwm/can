
/* Mode register */
`define CAN_MODE_RESET                  1'h1    /* Reset mode */

/* Bit Timing 0 register value */
//`define CAN_TIMING0_BRP                 6'h0    /* Baud rate prescaler (2*(value+1)) */
//`define CAN_TIMING0_SJW                 2'h2    /* SJW (value+1) */

`define CAN_TIMING0_BRP                 6'h3    /* Baud rate prescaler (2*(value+1)) */
`define CAN_TIMING0_SJW                 2'h1    /* SJW (value+1) */

/* Bit Timing 1 register value */
//`define CAN_TIMING1_TSEG1               4'h4    /* TSEG1 segment (value+1) */
//`define CAN_TIMING1_TSEG2               3'h3    /* TSEG2 segment (value+1) */
//`define CAN_TIMING1_SAM                 1'h0    /* Triple sampling */

`define CAN_TIMING1_TSEG1               4'hf    /* TSEG1 segment (value+1) */
`define CAN_TIMING1_TSEG2               3'h2    /* TSEG2 segment (value+1) */
`define CAN_TIMING1_SAM                 1'h0    /* Triple sampling */


