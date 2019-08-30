//
//  PotatsoManager.m
//  Potatso
//
//  Created by LEI on 4/4/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

#import "Potatso.h"

NSString *sharedGroupIdentifier = @"group.com.nina.mtfly2";
NSString *shadowsocksLogFile = @"shadowsocks.log";
NSString *privoxyLogFile = @"privoxy.log";

@implementation Potatso

+ (NSURL *)sharedUrl {
    return [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:sharedGroupIdentifier];
}

+ (NSURL *)sharedDatabaseUrl {
    return [[self sharedUrl] URLByAppendingPathComponent:@"potatso.realm" isDirectory:NO];
}

+ (NSUserDefaults *)sharedUserDefaults {
    return [[NSUserDefaults alloc] initWithSuiteName:sharedGroupIdentifier];
}

+ (NSURL * _Nonnull)sharedGeneralConfUrl {
    return [[Potatso sharedUrl] URLByAppendingPathComponent:@"general.xxx"  isDirectory:NO];
}

+ (NSURL *)sharedProxyConfUrl {
    return [[Potatso sharedUrl] URLByAppendingPathComponent:@"proxy.xxx"  isDirectory:NO];
}

+ (NSURL *)sharedHttpProxyConfUrl {
    return [[Potatso sharedUrl] URLByAppendingPathComponent:@"http.xxx"  isDirectory:NO];
}

+ (NSURL *)sharedLogUrl {
    return [[Potatso sharedUrl] URLByAppendingPathComponent:@"tunnel.log"  isDirectory:NO];
}

+ (NSInteger) logLevel {
    return [[Potatso sharedUserDefaults] integerForKey:kLoggingLevel];
}

+ (void) setLogLevel:(NSInteger) ll {
    [[Potatso sharedUserDefaults] setInteger:ll forKey:kLoggingLevel];
}
@end
