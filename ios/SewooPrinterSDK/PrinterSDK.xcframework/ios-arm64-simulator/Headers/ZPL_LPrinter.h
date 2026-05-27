//
//  ZPL_LPrinter.h
//  MobileLibrary
//
//  Created by OHSANG OK on 2/24/20.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// ZPL Label Printer Status
#define STS_ZPL_NORMAL                  0
#define STS_ZPL_SUCCESS                 0
#define STS_L_ZPL_COVER_OPEN            1
#define STS_L_ZPL_PAPER_EMPTY           2
#define STS_L_ZPL_RIBBON_EMPTY          4
#define STS_L_ZPL_PAPER_JAM             8
#define STS_L_ZPL_PAPER_MISMATCH        16
#define STS_L_ZPL_PAPER_COUNT_NEAR_END  32
#define STS_L_ZPL_PAPER_COUNT_EMPTY     64
#define STS_L_ZPL_BUFFER_FULL           128
#define STS_L_ZPL_TIMEOUT               -1
#define STS_L_ZPL_NOT_USING_PAPER_COUNT     -2

// Rotation
extern NSString * const ZPL_L_ROTATION_0;
extern NSString * const ZPL_L_ROTATION_90;
extern NSString * const ZPL_L_ROTATION_180;
extern NSString * const ZPL_L_ROTATION_270;

// Media
extern NSString * const ZPL_L_SENSE_CONTINUOUS;
extern NSString * const ZPL_L_SENSE_GAP;
extern NSString * const ZPL_L_SENSE_WEB;
extern NSString * const ZPL_L_SENSE_BLACKMARK;

// Device Font (Bitmap)
extern NSString * const ZPL_L_FONT_A;
extern NSString * const ZPL_L_FONT_B;
extern NSString * const ZPL_L_FONT_C;
extern NSString * const ZPL_L_FONT_D;
extern NSString * const ZPL_L_FONT_E;
extern NSString * const ZPL_L_FONT_F;
extern NSString * const ZPL_L_FONT_G;
extern NSString * const ZPL_L_FONT_H;

extern NSString * const ZPL_L_FONT_0;
extern NSString * const ZPL_L_FONT_1;
extern NSString * const ZPL_L_FONT_2;
extern NSString * const ZPL_L_FONT_3;
extern NSString * const ZPL_L_FONT_4;
extern NSString * const ZPL_L_FONT_5;
extern NSString * const ZPL_L_FONT_6;
extern NSString * const ZPL_L_FONT_7;
extern NSString * const ZPL_L_FONT_8;
extern NSString * const ZPL_L_FONT_9;

extern NSString * const ZPL_L_FONT_P;
extern NSString * const ZPL_L_FONT_Q;
extern NSString * const ZPL_L_FONT_R;
extern NSString * const ZPL_L_FONT_S;
extern NSString * const ZPL_L_FONT_T;
extern NSString * const ZPL_L_FONT_U;
extern NSString * const ZPL_L_FONT_V;

// Barcode Types
extern NSString * const ZPL_L_BCS_Code11;
extern NSString * const ZPL_L_BCS_Interleaved_2OF5;
extern NSString * const ZPL_L_BCS_Code39;
extern NSString * const ZPL_L_BCS_Code49;
extern NSString * const ZPL_L_BCS_PlanetCode;
extern NSString * const ZPL_L_BCS_PDF417;
extern NSString * const ZPL_L_BCS_EAN8;
extern NSString * const ZPL_L_BCS_UPCE;
extern NSString * const ZPL_L_BCS_Code93;
extern NSString * const ZPL_L_BCS_CODABLOCK;
extern NSString * const ZPL_L_BCS_Code128;
extern NSString * const ZPL_L_BCS_UPSMAXICODE;
extern NSString * const ZPL_L_BCS_EAN13;
extern NSString * const ZPL_L_BCS_MicroPDF417;
extern NSString * const ZPL_L_BCS_Industrial_2OF5;
extern NSString * const ZPL_L_BCS_Standard_2OF5;
extern NSString * const ZPL_L_BCS_Codabar;
extern NSString * const ZPL_L_BCS_LOGMARS;
extern NSString * const ZPL_L_BCS_MSI;
extern NSString * const ZPL_L_BCS_Aztec;
extern NSString * const ZPL_L_BCS_Plessey;
extern NSString * const ZPL_L_BCS_QRCode;
extern NSString * const ZPL_L_BCS_RSS;
extern NSString * const ZPL_L_BCS_UPCEANEXT;
extern NSString * const ZPL_L_BCS_TLC39;
extern NSString * const ZPL_L_BCS_UPCA;
extern NSString * const ZPL_L_BCS_DataMatrix;
extern NSString * const ZPL_L_BCS_POSTNET;

// QR Code ECL
extern NSString * const ZPL_L_QR_ECL_H;
extern NSString * const ZPL_L_QR_ECL_Q;
extern NSString * const ZPL_L_QR_ECL_M;
extern NSString * const ZPL_L_QR_ECL_L;

// DataMatrix Quality
#define ZPL_DM_QUALITY_0        0
#define ZPL_DM_QUALITY_50    50
#define ZPL_DM_QUALITY_80    80
#define ZPL_DM_QUALITY_100    100
#define ZPL_DM_QUALITY_140    140
#define ZPL_DM_QUALITY_200    200

// Graphic color
extern NSString * const ZPL_L_LINE_COLOR_W;
extern NSString * const ZPL_L_LINE_COLOR_B;

// Graphic Direction of Diagonal
extern NSString * const ZPL_L_DIAGONAL_R;
extern NSString * const ZPL_L_DIAGONAL_L;

// Auto Clear Buffer
#define ZPL_CLEAR_BUFFER_ON     1
#define ZPL_CLEAR_BUFFER_OFF     0
#define ZPL_CLEAR_BUFFER_STATUS_ON     49
#define ZPL_CLEAR_BUFFER_STATUS_OFF     48


@interface ZPL_LPrinter : NSObject
{
    BOOL startXA;
    NSStringEncoding encoding;
}

@property (nonatomic) BOOL startXA;
@property (nonatomic) NSStringEncoding encoding;

- (long) openPort:(NSString*)portName withPortParam:(int) port;
- (long) closePort;

// ZPL Command methods.
- (long) setInternationalFont:(int) internationalFont;
- (long) startPage;
- (long) endPage:(int) quantity;
- (long) setSpeed:(int) speed;
- (long) setDarkness:(int) darkness;
- (long) setupPrinter:(NSString *) orientation withmTrack:(NSString *) mTrack withWidth:(int) width withHeight:(int) height withCutmode:(int) cutmode;
- (long) printText:(NSString *) deviceFont withOrientation:(NSString *) orientation withWidth:(int) width withHeight:(int) height
    withPrintX:(int) printX withPrintY:(int) printY withData:(NSString *) data;
- (long) setBarcodeField:(int) moduleWidth withRatio:(NSString *) ratio withBarHeight:(int) barHeight;
- (long) printBarcode:(NSString *) barcodeType withBarcodeProp:(NSString *) barcodeProp withPrintX:(int) printX withPrintY:(int) printY withData:(NSString *) data;
- (long) printImage:(NSString *) filePath withPrintX:(int) printX withPrintY:(int) printY withBrightness:(int) bright;
- (long) printDiagonalLine:(int) printX withPrintY:(int) printY withWidth:(int) width withHeight:(int) height withThickness:(int) thickness
    withLineColor:(NSString *) lineColor withDirection:(NSString *) direction;
- (long) printCircle:(int) printX withPrintY:(int) printY withDiameter:(int) diameter withThickness:(int) thickness withLineColor:(NSString *) lineColor;
- (long) printEllipse:(int) printX withPrintY:(int) printY withWidth:(int) width withHeight:(int) height withThickness:(int) thickness
    withLineColor:(NSString *) lineColor;
- (long) printRectangle:(int) printX withPrintY:(int) printY withWidth:(int) width withHeight:(int) height withThickness:(int) thickness
    withLineColor:(NSString *) lineColor withRounding:(int) rounding;

// 2D Barcode
- (long) printPDF417:(int) printX withPrintY:(int) printY withOrientation:(NSString *) orientation withCellWidth:(int) cellWidth withSecurity:(int) security    withNumOfRow:(int) numOfRow withTruncate:(NSString *) truncate withData:(NSString *) data;
- (long) printDataMatrix:(int) printX withPrintY:(int) printY withOrientation:(NSString *) orientation withCellWidth:(int) cellWidth withQuality:(int) quality withData:(NSString *) data;
- (long) printQRCODE:(int) printX withPrintY:(int) printY withOrientation:(NSString *) orientation withModel:(int) model withCellWidth:(int) cellWidth withData:(NSString *) data;
- (long) directCommand:(NSString *) command;
- (long) printString:(NSString*) data;
- (long) printData:(unsigned char *) data withLength:(int) length;

// Check the printer status.
- (long) printerCheck;  //only Wi-Fi, not using Bluetooth
- (long) getPaperCount;
- (long) setPaperCount:(int) totalCount withLimitCount:(int) limitCount withMode:(int) mode;
- (long) resetPaperCount;
- (long) checkBufferFull;
- (long) printPdfFile:(NSString *) filePath withPage:(int) printPage withPrintWidth:(int) pSize;
- (long) printPdfFilePartial:(NSString *) filePath withStartPage:(int) startPage withEndPage:(int) endPage withPrintWidth:(int) pSize;
- (long) printFile:(NSString *)filePath;
- (long) setCharacterSet:(int) iCharSet;
- (long) setAutoClearBuffer:(int) mode; //Added 20.07.13
- (long) getAutoClearBuffer; //Added 20.07.13

@end
