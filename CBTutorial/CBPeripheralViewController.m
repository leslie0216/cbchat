//
//  CBPeripheralViewController.m
//  CBTutorial
//
//  Created by Orlando Pereira on 10/8/13.
//  Copyright (c) 2013 Mobiletuts. All rights reserved.
//

#import "CBPeripheralViewController.h"
#import "Messages.pbobjc.h"


@implementation CBPeripheralViewController
{
    NSTimer *timer;
}

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
    [timer invalidate];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"didSubscribeToCharacteristic");
    _dataToSend = [_textView.text dataUsingEncoding:NSUTF8StringEncoding];
    
    _sendDataIndex = 0;
    
    [self sendData];
    
    self.btnSend.enabled = TRUE;
    
    self.lbStatus.text = @"Connected";
    if (timer == nil) {
        timer = [NSTimer scheduledTimerWithTimeInterval:1.0/1000.0
                                                 target:self
                                               selector:@selector(showTimer)
                                               userInfo:nil
                                                repeats:YES];
    }
}

- (void) sendData
{
    if (self.sendDataIndex >= self.dataToSend.length) {
        self.btnSend.enabled = YES;
        return;
    }
    
    BOOL isComplete = NO;
    
    while (!isComplete) {
        TransferMessage *message = [[TransferMessage alloc]init];
        message.name = [[UIDevice currentDevice] name];
        message.time = [[NSDate date] timeIntervalSince1970] * 1000;
        //message.message = self.textView.text;
        
        NSInteger amountToSend = self.dataToSend.length - self.sendDataIndex;
        
        if (amountToSend > NOTIFY_MTU) {
            amountToSend = NOTIFY_MTU;
            NSLog(@"Send more than once!!!");
            isComplete = NO;
        } else {
            isComplete = YES;
        }
        
        message.complete = isComplete;
        
        NSData *chunk = [NSData dataWithBytes:self.dataToSend.bytes+self.sendDataIndex length:amountToSend];
        
        message.message = [[NSString alloc] initWithData:chunk encoding:NSUTF8StringEncoding];
        
        NSTimeInterval startTime = [[NSDate date] timeIntervalSince1970] * 1000;
        
        BOOL didSend = [self.peripheralManager updateValue:[message data] forCharacteristic:self.sendCharacteristic onSubscribedCentrals:nil];
        
        NSTimeInterval timeInterval = ([[NSDate date] timeIntervalSince1970] * 1000) - startTime;
        
        if (!didSend) {
            return;
        }
        
        [self updateHistory:timeInterval];
        
        NSString *stringFromData = [[NSString alloc] initWithData:chunk encoding:NSUTF8StringEncoding];
        NSLog(@"Sent : %@", stringFromData);
        
        self.sendDataIndex += amountToSend;
        
        self.btnSend.enabled = isComplete;
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
    
    _dataToSend = [self.textView.text dataUsingEncoding:NSUTF8StringEncoding];
    
    _sendDataIndex = 0;
    
    [self sendData];
}

- (void)updateHistory:(double) time
{
    NSString *history = [NSString stringWithFormat:@"(%f)Me: %@\n", time, _textView.text];
    [_textView_central_msg setText:[history stringByAppendingString:self.textView_central_msg.text]];
    
    [_textView setText:@""];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray<CBATTRequest *> *)requests
{
    for (CBATTRequest *request in requests) {
        if ([request.characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_CENTRAL_UUID]]) {
            
            [peripheral respondToRequest:request    withResult:CBATTErrorSuccess];
            
            TransferMessage *message = [[TransferMessage alloc] initWithData:request.value error:nil];
            
            if (message.complete) {
                NSString *remoteName = message.name;
                NSString *dataString = message.message;
                //double time = ([[NSDate date] timeIntervalSince1970] * 1000) - message.time;
                NSLog(@"Received from central - %@", dataString);
                
                NSString *history = [NSString stringWithFormat:@"%@: %@\n", remoteName, dataString];
                [_textView_central_msg setText:[history stringByAppendingString:self.textView_central_msg.text]];
            } else {
                NSLog(@"Received data is not complete!!!");
            }

            //[peripheral respondToRequest:request    withResult:CBATTErrorSuccess];
        }
    }
}

- (void)showTimer
{
    double time = [[NSDate date] timeIntervalSince1970] * 1000;;
    self.lbStatus.text = [NSString stringWithFormat:@"%lf", time];
}

@end
