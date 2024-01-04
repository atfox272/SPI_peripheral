/*  
    User can control SS pin in Software layer (comment the define below) or use internal SS controller (uncomment the define below)
    If user use internal SS controller, the SS pin will be LOW immediately upon receiving data from FIFO
*/
`define SS_INTERNAL_CONTROLLER