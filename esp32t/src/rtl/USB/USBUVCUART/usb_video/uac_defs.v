
`define USB_CLASS_AUDIO                 8'h01

/* A.2 Audio Interface Subclass Codes */
`define USB_AUDIO_CONTROL               8'h01
`define USB_AUDIO_STREAMING             8'h02
`define USB_AUDIO_MIDISTREAMING         8'h03

`define AF_VERSION_00_00                8'h00
`define AF_VERSION_02_00                8'h20

/* A.5 Audio Class-Specific AC Interface Descriptor Subtypes */
`define UAC_HEADER                      8'h01
`define UAC_INPUT_TERMINAL              8'h02
`define UAC_OUTPUT_TERMINAL             8'h03
`define UAC_MIXER_UNIT                  8'h04
`define UAC_SELECTOR_UNIT               8'h05
`define UAC_FEATURE_UNIT                8'h06
`define UAC1_PROCESSING_UNIT            8'h07
`define UAC1_EXTENSION_UNIT             8'h08

/* A.6 Audio Class-Specific AS Interface Descriptor Subtypes */
`define UAC_AS_GENERAL                  8'h01
`define UAC_FORMAT_TYPE                 8'h02
`define UAC_FORMAT_SPECIFIC             8'h03


/* A.9 Audio Class-Specific AC Interface Descriptor Subtypes */
/* see audio.h for the rest, which is identical to v1 */
`define UAC2_EFFECT_UNIT                8'h07
`define UAC2_PROCESSING_UNIT_V2         8'h08
`define UAC2_EXTENSION_UNIT_V2          8'h09
`define UAC2_CLOCK_SOURCE               8'h0a
`define UAC2_CLOCK_SELECTOR             8'h0b
`define UAC2_CLOCK_MULTIPLIER           8'h0c
`define UAC2_SAMPLE_RATE_CONVERTER      8'h0d

/* A.6 Audio Class-Specific AS Interface Descriptor Subtypes */
`define UAC_AS_GENERAL                  8'h01
`define UAC_FORMAT_TYPE                 8'h02
`define UAC_FORMAT_SPECIFIC             8'h03

/* A.7 Processing Unit Process Types */
`define UAC_PROCESS_UNDEFINED           8'h00
`define UAC_PROCESS_UP_DOWNMIX          8'h01
`define UAC_PROCESS_DOLBY_PROLOGIC      8'h02
`define UAC_PROCESS_STEREO_EXTENDER     8'h03
`define UAC_PROCESS_REVERB              8'h04
`define UAC_PROCESS_CHORUS              8'h05
`define UAC_PROCESS_DYN_RANGE_COMP      8'h06

/* A.8 Audio Class-Specific Endpoint Descriptor Subtypes */
`define UAC_EP_GENERAL                  8'h01

/* Terminals - 2.1 USB Terminal Types */
`define UAC_TERMINAL_UNDEFINED          16'h100
`define UAC_TERMINAL_STREAMING          16'h101
`define UAC_TERMINAL_VENDOR_SPEC        16'h1FF


/* Terminals - 2.2 Input Terminal Types */
`define UAC_INPUT_TERMINAL_UNDEFINED                    16'h200
`define UAC_INPUT_TERMINAL_MICROPHONE                   16'h201
`define UAC_INPUT_TERMINAL_DESKTOP_MICROPHONE           16'h202
`define UAC_INPUT_TERMINAL_PERSONAL_MICROPHONE          16'h203
`define UAC_INPUT_TERMINAL_OMNI_DIR_MICROPHONE          16'h204
`define UAC_INPUT_TERMINAL_MICROPHONE_ARRAY             16'h205
`define UAC_INPUT_TERMINAL_PROC_MICROPHONE_ARRAY        16'h206


/* Formats - A.1.1 Audio Data Format Type I Codes */
`define UAC_FORMAT_TYPE_I_UNDEFINED     32'h0
`define UAC_FORMAT_TYPE_I_PCM           32'h1
`define UAC_FORMAT_TYPE_I_PCM8          32'h2
`define UAC_FORMAT_TYPE_I_IEEE_FLOAT    32'h3
`define UAC_FORMAT_TYPE_I_ALAW          32'h4
`define UAC_FORMAT_TYPE_I_MULAW         32'h5

/* Formats - A.2 Format Type Codes */
`define UAC_FORMAT_TYPE_UNDEFINED       8'h0
`define UAC_FORMAT_TYPE_I               8'h1
`define UAC_FORMAT_TYPE_II              8'h2
`define UAC_FORMAT_TYPE_III             8'h3
`define UAC_EXT_FORMAT_TYPE_I           8'h81
`define UAC_EXT_FORMAT_TYPE_II          8'h82
`define UAC_EXT_FORMAT_TYPE_III         8'h83

`define USB_DESCTYPE_CS_ENDPOINT        8'h25

`define UAC_CUR_ATTR			8'd1
`define UAC_RANGE_ATTR			8'd2

`define CS_SAM_FREQ_CONTROL		8'd1

`define UAC_FREQUENCY                   32'd44100

`define UAC_CLOCK_ID			1

`define AUDIO_DATA_EP_NUM               8'h05 /* (8'h85) */
`define UAC_PACKET_SIZE                 11'd24

`define UAC_INTERFACE_BASE		4
`define UAC_AC_INTERFACE		(`UAC_INTERFACE_BASE)
`define UAC_AS_INTERFACE		(`UAC_INTERFACE_BASE + 1)
