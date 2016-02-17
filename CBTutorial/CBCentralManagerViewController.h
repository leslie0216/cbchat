//
//  CBCentralManagerViewController.h
//  CBTutorial
//
//  Created by Orlando Pereira on 10/8/13.
//  Copyright (c) 2013 Mobiletuts. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>

#import "SERVICES.h"

@interface CBCentralManagerViewController : UIViewController<CBCentralManagerDelegate, CBPeripheralDelegate>

@property (strong, nonatomic) IBOutlet UITextView *textview;
@property (strong, nonatomic) IBOutlet UITextView *textview_peripheral_msg;
@property (weak, nonatomic) IBOutlet UIButton *btnSend;
@property (weak, nonatomic) IBOutlet UILabel *lbStatus;
@property (weak, nonatomic) IBOutlet UIButton *btnPing;
@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *discoveredPeripheral;
@property (strong, nonatomic) NSMutableData *data;

@property (strong, nonatomic) NSData *dataToSend;
@property (nonatomic, readwrite) NSInteger sendDataIndex;

@property (strong, nonatomic) CBCharacteristic *readCharacteristic;
@property (strong, nonatomic) CBCharacteristic *writeCharacteristic;

- (IBAction)sendMsg:(id)sender;
- (IBAction)ping:(id)sender;

@end
