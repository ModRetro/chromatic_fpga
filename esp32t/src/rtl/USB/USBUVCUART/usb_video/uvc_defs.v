/* USB Video device product defines */
`define BCD_DEVICE  16'h0100
`define VENDOR_ID   16'h20B1
`define PRODUCT_ID  16'h1DE0

/* USB Sub class and Protocol codes */
`define USB_VIDEO_CONTROL               8'h01
`define USB_VIDEO_STREAMING             8'h02
`define USB_VIDEO_INTERFACE_COLLECTION  8'h03

/* Descriptor types */
`define USB_DESCTYPE_CS_INTERFACE   8'h24
`define USB_DESCTYPE_CS_ENDPOINT    8'h25

/* USB Video Control Subtype Descriptors */
`define USB_VC_HEADER           8'h01
`define USB_VC_INPUT_TERMINAL   8'h02
`define USB_VC_OUPUT_TERMINAL   8'h03
`define USB_VC_SELECTOR_UNIT    8'h04
`define USB_VC_PROCESSING_UNIT  8'h05

/* USB Video Streaming Subtype Descriptors */
`define USB_VS_INPUT_HEADER         8'h01
`define USB_VS_OUPUT_HEADER         8'h02
`define USB_VS_STILL_IMAGE_FRAME    8'h03
`define USB_VS_FORMAT_UNCOMPRESSED  8'h04
`define USB_VS_FRAME_UNCOMPRESSED   8'h05
`define USB_VS_FORMAT_MJPEG         8'h06
`define USB_VS_FRAME_MJPEG          8'h07

///* To split numbers into Little Endian format */
//`define WORD_CHARS(x)   (x&8'hff), ((x>>8)&8'hff), ((x>>16)&8'hff), ((x>>24)&8'hff)
//`define SHORT_CHARS(x)  (x&8'hff), ((x>>8)&8'hff)

/* Endpoint Addresses for Video device */
`define VIDEO_STATUS_EP_NUM         8'h01 /* (8'h81) */
`define VIDEO_DATA_EP_NUM           8'h02 /* (8'h82) */

/* Video Class-specific Request codes */
`define SET_CUR     8'h01
`define GET_CUR     8'h81
`define GET_MIN     8'h82
`define GET_MAX     8'h83
`define GET_RES     8'h84
`define GET_LEN     8'h85
`define GET_INFO    8'h86
`define GET_DEF     8'h87

/* Video Streaming Interface Control selectors */
`define VS_PROBE_CONTROL        8'h01
`define VS_COMMIT_CONTROL       8'h02

/* Video Stream related */
`define PAYLOAD_HEADER_LENGTH 8'd12

/* USB Video resolution */
`define BITS_PER_PIXEL  8'd16
`define WIDTH           16'd160
`define HEIGHT          16'd144

/* Frame rate */
`define FPS  60
`define FPS_MAX  60
`define FPS_MIN  1

`define MAX_FRAME_SIZE (`WIDTH * `HEIGHT * `BITS_PER_PIXEL / 8)
`define MIN_BIT_RATE   (`MAX_FRAME_SIZE * `FPS_MIN * 8)
`define MAX_BIT_RATE   (`MAX_FRAME_SIZE * `FPS_MAX * 8)
/* Only single packet per mframe supported */
`define PACKET_PER_MFRAME   (1)
/* usb code here does not handle additional packets, keep at 0 */
`define ADDITIONAL_PACKET   (16'd0)
`define PACKET_SIZE    (12'd1024)
`define PAYLOAD_SIZE   (`PACKET_PER_MFRAME * `PACKET_SIZE)
`define DEVICE_CLOCK_FREQUENCY (32'd60000000)

/* Interval defined in 100ns units */
`define FRAME_INTERVAL  (32'd10000000/`FPS)
