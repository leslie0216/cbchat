//
//  CBPeripheralViewController.m
//  CBTutorial
//
//  Created by Orlando Pereira on 10/8/13.
//  Copyright (c) 2013 Mobiletuts. All rights reserved.
//

#import "CBPeripheralViewController.h"


@implementation CBPeripheralViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _textView.delegate = self;
    
    _peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
    
    self.btnSend.enabled = FALSE;
    
    self.lbStatus.text = @"Not Connected";
}


- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    if (peripheral.state != CBPeripheralManagerStatePoweredOn) {
        return;
    }
    
    if (peripheral.state == CBPeripheralManagerStatePoweredOn) {
        self.sendCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_PERIPHERAL_UUID] properties:CBCharacteristicPropertyNotify value:nil permissions:CBAttributePermissionsReadable];
        
        self.receiveCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_CENTRAL_UUID] properties:CBCharacteristicPropertyWrite value:nil permissions:CBAttributePermissionsWriteable];
        
        CBMutableService *transferService = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID] primary:YES];
        
        transferService.characteristics = @[_sendCharacteristic, _receiveCharacteristic];
        
        [_peripheralManager addService:transferService];
        
        [_peripheralManager startAdvertising:@{CBAdvertisementDataServiceUUIDsKey:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]]}];
        
        self.lbStatus.text = @"Advertising";
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"didSubscribeToCharacteristic");
    self.btnSend.enabled = FALSE;
    self.lbStatus.text = @"Not Connected";
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"didSubscribeToCharacteristic");
    _dataToSend = [_textView.text dataUsingEncoding:NSUTF8StringEncoding];
    
    _sendDataIndex = 0;
    
    [self sendData];
    
    self.btnSend.enabled = TRUE;
    
    self.lbStatus.text = @"Connected";
}

- (void) sendData
{
    static BOOL sendingEOM = NO;
    
    if (sendingEOM) {
        BOOL didSend = [self.peripheralManager updateValue:[@"EOM" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.sendCharacteristic onSubscribedCentrals:nil];
        
        if (didSend) {
            sendingEOM = NO;
            self.btnSend.enabled = TRUE;
        }
        return;
    }
    
    if (self.sendDataIndex >= self.dataToSend.length) {
        return;
    }
    
    BOOL didSend = YES;
    
    while (didSend) {
        NSInteger amountToSend = self.dataToSend.length - self.sendDataIndex;
        
        if (amountToSend > NOTIFY_MTU) {
            amountToSend = NOTIFY_MTU;
        }
        
        NSData *chunk = [NSData dataWithBytes:self.dataToSend.bytes+self.sendDataIndex length:amountToSend];
        
        didSend = [self.peripheralManager updateValue:chunk forCharacteristic:self.sendCharacteristic onSubscribedCentrals:nil];
        
        if (!didSend) {
            return;
        }
        
        NSString *stringFromData = [[NSString alloc] initWithData:chunk encoding:NSUTF8StringEncoding];
        NSLog(@"Sent : %@", stringFromData);
        
        self.sendDataIndex += amountToSend;
        
        if (self.sendDataIndex >= self.dataToSend.length) {
            sendingEOM = YES;
            self.btnSend.enabled = FALSE;
            
            BOOL eomSent = [self.peripheralManager updateValue:[@"EOM" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.sendCharacteristic onSubscribedCentrals:nil   ];
            
            if (eomSent) {
                sendingEOM = NO;
                self.btnSend.enabled = TRUE;
                NSLog(@"Sent : EOM");
            }
        }
    }
}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
    [self sendData];
}


- (IBAction)sendMsg:(id)sender
{
    self.btnSend.enabled = FALSE;

    [_textView resignFirstResponder];
    
    _dataToSend = [_textView.text dataUsingEncoding:NSUTF8StringEncoding];
    
    _sendDataIndex = 0;
    
    [self sendData];
    
    NSString *history = [NSString stringWithFormat:@"Me: %@\n", _textView.text];
    [_textView_central_msg setText:[history stringByAppendingString:self.textView_central_msg.text]];
    
    [_textView setText:@""];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray<CBATTRequest *> *)requests
{
    for (CBATTRequest *request in requests) {
        if ([request.characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_CENTRAL_UUID]]) {

            NSString *dataString = [[NSString alloc] initWithData:request.value encoding:NSUTF8StringEncoding];
            NSLog(@"Received from central - %@", dataString);
            
            NSString *history = [NSString stringWithFormat:@"Remote: %@\n", dataString];
            [_textView_central_msg setText:[history stringByAppendingString:self.textView_central_msg.text]];

            [peripheral respondToRequest:request    withResult:CBATTErrorSuccess];
        }
    }
}

@end
