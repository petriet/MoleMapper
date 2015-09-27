//
//  BridgeManager.m
//  MoleMapper
//
//  Created by Dan Webster on 8/19/15.
//  Copyright (c) 2015 Webster Apps. All rights reserved.
//

#import "BridgeManager.h"
#import "Measurement.h"
#import "Measurement+MakeAndMod.h"
#import "Mole.h"
#import "Mole+MakeAndMod.h"
#import "Zone.h"
#import "ZipArchive.h"
#import "APCDataArchiveUploader.h"
#import "APCLog.h"
#import "AppDelegate.h"



//Class to handle data transfer to BridgeServer
@implementation BridgeManager


//Derived from APCUser+Bridge
- (void)sendUserConsentedToBridgeOnCompletion:(void (^)(NSError *))completionBlock
{
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSString *name = @"Name not provided";
    NSLog(@"firstName: %@, lastName: %@",ad.user.firstName, ad.user.lastName);
    if (ad.user.firstName && ad.user.lastName)
    {
        name = [NSString stringWithFormat:@"%@ %@",ad.user.firstName,ad.user.lastName];
    }
    
    /*Because user has not entered their birthdate yet (will happen in initial survey), but
    the bridge server call to set the consent needs a non-nill date, need to put something in,
    and this will be overwritten later when the initial survey is completed */
    NSDate *birthdate = [NSDate dateWithTimeIntervalSince1970:0.0];
    if (ad.user.birthdateForProfile)
    {
        birthdate =  ad.user.birthdateForProfile;
    }
    
    UIImage *signatureImage = ad.user.signatureImage;
    
    //Because all KeyChain-stored items are strings, have to go through conversion here
    NSString *sharingScopeString = ad.user.sharingScope;
    NSNumber *sharingScopeNumber = @([sharingScopeString intValue]);
    
    [SBBComponent(SBBConsentManager) consentSignature:name
                                            birthdate:birthdate
                                       signatureImage:signatureImage
                                          dataSharing:[sharingScopeNumber integerValue]
                                           completion:^(id __unused responseObject, NSError * __unused error) {
                                               dispatch_async(dispatch_get_main_queue(), ^{
                                                   if (!error) {
                                                       APCLogEventWithData(@"Network Event", (@{@"event_detail":@"User Consent Sent To Bridge"}));
                                                   }
                                                   
                                                   if (completionBlock) {
                                                       completionBlock(error);
                                                   }
                                               });
                                           }];
    
}

//Derived from APCUser+Bridge
- (void) updateProfileOnCompletion:(void (^)(NSError *))completionBlock
{
    /*if ([self serverDisabled]) {
     if (completionBlock) {
     completionBlock(nil);
     }
     }
     else
     {*/
    
    SBBUserProfile *profile = [SBBUserProfile new];
    
    AppDelegate *ad = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    if (ad.user.bridgeSignInEmail) {profile.email = ad.user.bridgeSignInEmail;}
    if (ad.user.bridgeSignInEmail) {profile.username = ad.user.bridgeSignInEmail;}
    if (ad.user.firstName) {profile.firstName = ad.user.firstName;}
    if (ad.user.lastName) {profile.lastName = ad.user.lastName;}
    
    //**Note** As of most recent IRB submission, this data will not be transferred to Bridge Server Profile
    // but will be securely stored locally in the keychain in case there is a change later
    //if (ad.user.zipCode) {profile.zipCode = ad.user.zipCode;}
    //if (ad.user.melanomaStatus) {profile.melanomaDiagnosis = ad.user.melanomaStatus;}
    //if (ad.user.familyHistory) {profile.familyHistory = ad.user.familyHistory;}
    //if (ad.user.birthdate) {profile.birthdate = ad.user.birthdate;}
    
    [SBBComponent(SBBUserManager) updateUserProfileWithProfile: profile
                                                    completion: ^(id __unused responseObject,
                                                                  NSError *error)
     {
         dispatch_async(dispatch_get_main_queue(), ^{
             if (!error)
             {
                 NSLog(@"User Profile Updated To Bridge");
             }
             if (completionBlock)
             {
                 completionBlock(error);
             }
         });
     }];
    
}


-(void)signInAndSendInitialData:(NSDictionary *)initialData
{
    AppDelegate *ad = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    if (ad.user.bridgeSignInEmail && ad.user.bridgeSignInPassword)
    {
        [SBBComponent(SBBAuthManager) signInWithUsername: ad.user.bridgeSignInEmail
                                                password: ad.user.bridgeSignInPassword
                                              completion: ^(NSURLSessionDataTask * __unused task,
                                                            id responseObject,
                                                            NSError *signInError)
         {
             dispatch_async(dispatch_get_main_queue(), ^{
                 if (!signInError)
                 {
                     /*
                      NSDictionary *responseDictionary = (NSDictionary *) responseObject;
                      if (responseDictionary)
                      {
                      NSNumber *dataSharing = responseDictionary[@"dataSharing"];
                      NSLog(@"Data sharing scope integer is %@",dataSharing);
                      }
                      */
                     
                     NSLog(@"User is Signed In");
                     [ad.bridgeManager zipEncryptAndShipInitialData:initialData];
                 }
                 else
                 {
                     NSLog(@"Error during log in before followup: %@",signInError);
                 }
                 
             });
         }
         ];
    }
}


-(void)signInAndSendFollowupData:(NSDictionary *)followupData
{
    AppDelegate *ad = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    if (ad.user.bridgeSignInEmail && ad.user.bridgeSignInPassword)
    {
        [SBBComponent(SBBAuthManager) signInWithUsername: ad.user.bridgeSignInEmail
                                                password: ad.user.bridgeSignInPassword
                                              completion: ^(NSURLSessionDataTask * __unused task,
                                                            id responseObject,
                                                            NSError *signInError)
         {
             dispatch_async(dispatch_get_main_queue(), ^{
                 if (!signInError)
                 {
                     /*
                      NSDictionary *responseDictionary = (NSDictionary *) responseObject;
                      if (responseDictionary)
                      {
                      NSNumber *dataSharing = responseDictionary[@"dataSharing"];
                      NSLog(@"Data sharing scope integer is %@",dataSharing);
                      }
                      */
                     
                     NSLog(@"User is Signed In");
                     [ad.bridgeManager zipEncryptAndShipFollowupData:followupData];
                 }
                 else
                 {
                     NSLog(@"Error during log in before followup: %@",signInError);
                 }
                 
             });
         }
         ];
    }
}

-(void)signInAndSendMeasurements
{
    AppDelegate *ad = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    if (ad.user.bridgeSignInEmail && ad.user.bridgeSignInPassword)
    {
        [SBBComponent(SBBAuthManager) signInWithUsername: ad.user.bridgeSignInEmail
                                                password: ad.user.bridgeSignInPassword
                                              completion: ^(NSURLSessionDataTask * __unused task,
                                                            id responseObject,
                                                            NSError *signInError)
         {
             dispatch_async(dispatch_get_main_queue(), ^{
                 if (!signInError)
                 {
                     /*
                      NSDictionary *responseDictionary = (NSDictionary *) responseObject;
                      if (responseDictionary)
                      {
                      NSNumber *dataSharing = responseDictionary[@"dataSharing"];
                      NSLog(@"Data sharing scope integer is %@",dataSharing);
                      }
                      */
                     
                     NSLog(@"User is Signed In");
                     [ad.bridgeManager zipEncryptAndShipAllMoleMeasurementData];
                 }
                 else
                 {
                     NSLog(@"Error during log in: %@",signInError);
                 }
                 
             });
         }
         ];
    }
    
}

-(void)zipEncryptAndShipInitialData:(NSDictionary *)initialData
{
    APCDataArchive *archive = [[APCDataArchive alloc] initWithReference:@"initialData"];
    //Note that contrary to documentation, you need the file extension here to be recognized by Bridge Server
    [archive insertIntoArchive:initialData filename:@"initialData.json"];
    
    APCDataArchiveUploader *uploader = [[APCDataArchiveUploader alloc] init];
    
    //Using call from APCBaseTaskViewController here
    [uploader encryptAndUploadArchive:archive withCompletion:^(NSError *error) {
        if (! error) { NSLog(@"Encrypt/uploading followup..."); }
        else { APCLogError2(error); }
    }];
}

-(void)zipEncryptAndShipFollowupData:(NSDictionary *)followupData
{
    APCDataArchive *archive = [[APCDataArchive alloc] initWithReference:@"followup"];
    //Note that contrary to documentation, you need the file extension here to be recognized by Bridge Server
    [archive insertIntoArchive:followupData filename:@"followup.json"];
    
    APCDataArchiveUploader *uploader = [[APCDataArchiveUploader alloc] init];
    
    //Using call from APCBaseTaskViewController here
    [uploader encryptAndUploadArchive:archive withCompletion:^(NSError *error) {
        if (! error) { NSLog(@"Encrypt/uploading followup..."); }
        else { APCLogError2(error); }
    }];
    
}

-(void)zipEncryptAndShipAllMoleMeasurementData
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Measurement"];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"measurementID" ascending:YES]];
    NSError *error = nil;
    NSArray *fetchedMeasurements = [self.context executeFetchRequest:request error:&error];
    
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    //Contains a set of all of the measurementIDs that have successfully been sent
    NSArray *immutable = [ud objectForKey:@"measurementsAlreadySentToBridge"];
    NSMutableArray *measurementsAlreadySent = [immutable mutableCopy];
    
    for (Measurement *measurement in fetchedMeasurements)
    {
        if ([measurementsAlreadySent containsObject:measurement.measurementID])
        {
            continue; //Don't send duplicate measurements to Bridge
        }
        
        //AppDelegate *ad = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        //NSLog(@"BridgeSigninEmail = %@",ad.user.bridgeSignInEmail);
        //NSLog(@"BridgeSigninPassword = %@",ad.user.bridgeSignInPassword);
        
        NSDictionary *measurementData = [self dictionaryForMeasurement:measurement];
        
        //Get .png file for Bridge File
        NSData *measurementPngData = [Measurement rawPngDataForMeasurement:measurement];
        //NSData *measurementPngData = UIImagePNGRepresentation(self.testPng1);
        
        APCDataArchive *archive = [[APCDataArchive alloc] initWithReference:@"moleMeasurement"];
        [archive insertIntoArchive:measurementData filename:@"measurementData.json"];
        [archive insertDataIntoArchive:measurementPngData filename:@"measurementPhoto.png"];
        
        APCDataArchiveUploader *uploader = [[APCDataArchiveUploader alloc] init];
        
        //Using call from APCBaseTaskViewController here
        [uploader encryptAndUploadArchive:archive withCompletion:^(NSError *error) {
            if (! error)
            {
                NSLog(@"Encrypt/uploading mole measurement for mole: %@",measurement.whichMole.moleName);
                //Ideally would only add here after successfully sent, but the whole archive is encrypted and sent off at this point
                [measurementsAlreadySent addObject:measurement.measurementID];
            }
            else { APCLogError2(error); }
        }];
    }
    NSArray *arrayWithAddedMeasurements = [NSArray arrayWithArray:measurementsAlreadySent];
    
    [ud setObject:arrayWithAddedMeasurements forKey:@"measurementsAlreadySentToBridge"];
}

//Mole Measurement Schema
/*
 moleMeasurement
 measurementData.json.zoneID - string
 measurementData.json.moleID - int
 measurementData.json.yCoordinate - float
 measurementData.json.diameter - float
 measurementData.json.dateMeasured - timestamp
 measurementData.json.xCoordinate - float
 measurementData.json.measurementID - string
 measurementPhoto.png - attachment_blob
 */
-(NSDictionary *)dictionaryForMeasurement:(Measurement *)measurement
{
    NSMutableDictionary *measurementData = [NSMutableDictionary dictionary];
    NSString *measurementUUID = [[NSUUID UUID] UUIDString];
    [measurementData setValue:measurementUUID forKey:@"measurementID"];
    [measurementData setValue:[measurement.whichMole.moleID stringValue] forKey:@"moleID"];
    [measurementData setValue:measurement.whichMole.whichZone.zoneID forKey:@"zoneID"];
    [measurementData setValue:measurement.whichMole.moleX forKey:@"xCoordinate"];
    [measurementData setValue:measurement.whichMole.moleY forKey:@"yCoordinate"];
    //NOTE THAT NSJSON SERIALIZATION CAN'T HANDLE NSDATES!!
    [measurementData setValue:[self iso8601stringFromDate:measurement.date] forKey:@"dateMeasured"];
    [measurementData setValue:measurement.absoluteMoleDiameter forKey:@"diameter"];
    return measurementData;
}

-(NSString *)iso8601stringFromDate:(NSDate *)date
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    [dateFormatter setLocale:enUSPOSIXLocale];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
    
    NSString *iso8601String = [dateFormatter stringFromDate:date];
    return iso8601String;
}


@end
