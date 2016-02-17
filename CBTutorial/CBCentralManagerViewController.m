//
//  CBCentralManagerViewController.m
//  CBTutorial
//
//  Created by Orlando Pereira on 10/8/13.
//  Copyright (c) 2013 Mobiletuts. All rights reserved.
//

#import "CBCentralManagerViewController.h"
#import "Messages.pbobjc.h"

@implementation CBCentralManagerViewController
{
    NSTimer *timer;
    NSTimeInterval starTime;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    _data = [[NSMutableData alloc] init];
    self.btnSend.enabled = FALSE;
    self.lbStatus.text = @"Not Connected";
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_centralManager stopScan];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state != CBCentralManagerStatePoweredOn) {
        return;
    }
    
    if (central.state == CBCentralManagerStatePoweredOn) {
        [_centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]]  options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @YES}] ;
        NSLog(@"Scanning started");
        self.lbStatus.text = @"Scanning";
    }
}

- (void) centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"Discovered %@ at %@", peripheral.name, RSSI);
    
    if (_discoveredPeripheral != peripheral) {
        _discoveredPeripheral = peripheral;
        
        NSLog(@"Connecting to peripheral %@", peripheral);
        [_centralManager connectPeripheral:peripheral options:nil];
        
        self.lbStatus.text = @"Connecting";
    }
}

- (void) centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Failed to connect");
    [self cleanup];
}

- (void) cleanup
{
    if (_discoveredPeripheral.services !=nil)
    {
        for (CBService *service in _discoveredPeripheral.services)
        {
            if (service.characteristics != nil)
            {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_PERIPHERAL_UUID]])
                    {
                        if (characteristic.isNotifying) {
                            [_discoveredPeripheral setNotifyValue:NO forCharacteristic:characteristic];
                        }
                    }
                }
            }
        }
    }
    [_centralManager cancelPeripheralConnection:_discoveredPeripheral];
    self.btnSend.enabled = FALSE;
    self.lbStatus.text = @"Not Connected";
    [timer invalidate];
}

- (void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Connected to %@", peripheral.name);
    
    [_centralManager stopScan];
    NSLog(@"Scanning stopped");
    
    [_data setLength:0];
    
    peripheral.delegate = self;
    
    [peripheral discoverServices:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]]];
    self.lbStatus.text = @"SDiscovering";
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error)
    {
        [self cleanup];
        return;
    }
    
    for (CBService *service in peripheral.services)
    {
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_PERIPHERAL_UUID], [CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_CENTRAL_UUID]] forService:service];
        
        self.lbStatus.text = @"CDiscovering";
    }
}

- (void) peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (error) {
        [self cleanup];
        return;
    }
    
    for (CBCharacteristic *characteristic in service.characteristics)
    {
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_PERIPHERAL_UUID]])
        {
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            self.readCharacteristic = characteristic;
        }
        
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_CENTRAL_UUID]])
        {
            self.writeCharacteristic = characteristic;
            self.btnSend.enabled = TRUE;
        }
    }
    
    self.lbStatus.text = @"Connected";
    if (timer == nil) {
        timer = [NSTimer scheduledTimerWithTimeInterval:1.0/1000.0
                                                     target:self
                                                   selector:@selector(showTimer)
                                                   userInfo:nil
                                                    repeats:YES];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Errpr");
        return;
    }
    
    if (![characteristic isEqual:self.readCharacteristic]) {
        return;
    }
    
    TransferMessage *message = [[TransferMessage alloc] initWithData:characteristic.value error:nil];
    
    if (message.complete)
    {
        NSString *name = message.name;
        //double time = ([[NSDate date] timeIntervalSince1970] * 1000) - message.time;
        
        [self.data appendData:[message.message dataUsingEncoding:NSUTF8StringEncoding]];
        
        NSString *msg = [[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding];
        
        NSString *history = [NSString stringWithFormat:@"%@: %@\n", name, msg];

        [_textview_peripheral_msg setText:[history stringByAppendingString:self.textview_peripheral_msg.text]];

        
        [_data setLength:0];
         
        //[peripheral setNotifyValue:NO forCharacteristic:characteristic];
         
        //[_centralManager cancelPeripheralConnection:peripheral];
    } else {
        [_data appendData:[message.message dataUsingEncoding:NSUTF8StringEncoding]];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_PERIPHERAL_UUID]]) {
        return;
    }
    
    if (characteristic.isNotifying) {
        NSLog(@"Notification began on %@", characteristic);
    } else {
        [_centralManager cancelPeripheralConnection:peripheral];
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    [_centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]] options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@YES}];
}

- (IBAction)sendMsg:(id)sender
{
    self.btnSend.enabled = FALSE;
    
    [_textview resignFirstResponder];
    
    NSLog(@"Sent : %@", _textview.text);
    
    _dataToSend = [_textview.text dataUsingEncoding:NSUTF8StringEncoding];
    
    _sendDataIndex = 0;
    
    [self sendData];
}

- (void)sendData
{
    TransferMessage *message = [[TransferMessage alloc]init];
    message.name = [[UIDevice currentDevice] name];
    message.time = [[NSDate date] timeIntervalSince1970] * 1000;
    message.complete = YES;
    message.message = [[NSString alloc] initWithData:self.dataToSend encoding:NSUTF8StringEncoding];
    
    starTime = [[NSDate date] timeIntervalSince1970] * 1000;
    [_discoveredPeripheral writeValue:[message data] forCharacteristic:self.writeCharacteristic type:CBCharacteristicWriteWithResponse];
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSTimeInterval timeInterval = ([[NSDate date] timeIntervalSince1970] * 1000) - starTime;
    [self updateHistory:timeInterval];
    
    self.btnSend.enabled = TRUE;
    
    if (error)
    {
        NSLog(@"Central write Error : %@", error);
        return;
    }
}

- (void)updateHistory:(double) time
{
    NSString *history = [NSString stringWithFormat:@"(%f)Me: %@\n", time, _textview.text];
    [_textview_peripheral_msg setText:[history stringByAppendingString:self.textview_peripheral_msg.text]];
    
    [_textview setText:@""];
}

- (void)showTimer
{
    double time = [[NSDate date] timeIntervalSince1970] * 1000;;
    self.lbStatus.text = [NSString stringWithFormat:@"%lf", time];
}

@end
