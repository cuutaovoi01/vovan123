// libCrossOverIPC (reimplementation) — fix singleton overwrite bug.
// Moi center = instance rieng; observer giu instance; register/send theo instance.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <CoreFoundation/CoreFoundation.h>
extern CFNotificationCenterRef CFNotificationCenterGetDistributedCenter(void);

static NSMutableArray *g_keepAlive = nil;

@interface PlistManager : NSObject
+ (instancetype)shared;
- (id)objectForKey:(NSString *)k;
- (void)setObject:(id)v forKey:(NSString *)k;
- (void)removeObjectForKey:(NSString *)k;
@end

@interface CrossOverIPC : NSObject
@property (nonatomic, copy) NSString *origServiceName;
@property (nonatomic, copy) NSString *senderServiceName;
@property (nonatomic, copy) NSString *clientServiceName;
@property (nonatomic, copy) NSString *serviceName;
@property (nonatomic, strong) NSMutableDictionary *registeredTargets;
@property (nonatomic, assign) BOOL isSender;
+ (instancetype)shared;
+ (instancetype)centerNamed:(NSString *)name type:(NSInteger)type;
- (instancetype)initWithServiceNamed:(NSString *)name type:(NSInteger)type;
- (void)registerForMessageName:(NSString *)msg target:(id)target selector:(SEL)sel;
- (void)sendMessageName:(NSString *)msg userInfo:(NSDictionary *)info;
- (id)sendMessageAndReceiveReplyName:(NSString *)msg userInfo:(NSDictionary *)info;
- (void)handleNotificationName:(NSString *)name userInfo:(NSDictionary *)userInfo;
@end

static void co_callback(CFNotificationCenterRef center, void *observer, CFNotificationName name,
                        const void *object, CFDictionaryRef userInfo) {
    CrossOverIPC *self = (__bridge CrossOverIPC *)observer;
    if (!self) return;
    @try {
        [self handleNotificationName:(__bridge NSString *)name
                            userInfo:(__bridge NSDictionary *)userInfo];
    } @catch (NSException *e) {
    }
}

@implementation PlistManager
+ (instancetype)shared {
    static PlistManager *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [PlistManager new]; });
    return s;
}
static NSMutableDictionary *g_pm = nil;
- (id)objectForKey:(NSString *)k {
    @synchronized(self) { return g_pm[k]; }
}
- (void)setObject:(id)v forKey:(NSString *)k {
    @synchronized(self) {
        if (!g_pm) g_pm = [NSMutableDictionary new];
        if (v && k) g_pm[k] = v;
    }
}
- (void)removeObjectForKey:(NSString *)k {
    @synchronized(self) { [g_pm removeObjectForKey:k]; }
}
@end

@implementation CrossOverIPC
+ (instancetype)shared {
    static CrossOverIPC *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [CrossOverIPC new]; s.registeredTargets = [NSMutableDictionary new]; });
    return s;
}
+ (instancetype)centerNamed:(NSString *)name type:(NSInteger)type {
    return [[CrossOverIPC alloc] initWithServiceNamed:name type:type];
}
- (instancetype)initWithServiceNamed:(NSString *)name type:(NSInteger)type {
    self = [super init];
    if (!self) return nil;
    _registeredTargets = [NSMutableDictionary new];
    _origServiceName = [name copy];
    _senderServiceName = [[NSString alloc] initWithFormat:@"%@-CROSS_OVER_SENDER", name];
    _clientServiceName = [[NSString alloc] initWithFormat:@"%@-CROSS_OVER_CLIENT", name];
    _isSender = (type == 0);
    _serviceName = _isSender ? _senderServiceName : _clientServiceName;

    static dispatch_once_t once;
    dispatch_once(&once, ^{ g_keepAlive = [NSMutableArray new]; });
    @synchronized(g_keepAlive) { [g_keepAlive addObject:self]; }

    CFNotificationCenterRef dc = CFNotificationCenterGetDistributedCenter();
    CFNotificationCenterAddObserver(dc, (__bridge const void *)self, co_callback,
                                    (__bridge CFStringRef)_serviceName, NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    return self;
}
- (NSString *)purifyClientName:(NSString *)s {
    return [s stringByReplacingOccurrencesOfString:@"-CROSS_OVER_CLIENT" withString:@""];
}
- (void)registerForMessageName:(NSString *)msg target:(id)target selector:(SEL)sel {
    if (!msg || !target) return;
    NSString *key = [NSString stringWithFormat:@"%@~%@", self.serviceName, msg];
    self.registeredTargets[key] = @[target, NSStringFromSelector(sel)];
}
- (void)sendMessageName:(NSString *)msg userInfo:(NSDictionary *)info {
    if (!msg) return;
    NSDictionary *payload = @{
        @"msgName": msg,
        @"isWithReply": @"NO",
        @"clientServiceName": self.clientServiceName ?: @"",
        msg: info ?: @{},
    };
    CFDictionaryRef cf = (__bridge CFDictionaryRef)payload;
    CFNotificationCenterRef dc = CFNotificationCenterGetDistributedCenter();
    CFNotificationCenterPostNotificationWithOptions(dc,
                                                    (__bridge CFStringRef)self.clientServiceName,
                                                    NULL, cf, 3u);
}
- (id)sendMessageAndReceiveReplyName:(NSString *)msg userInfo:(NSDictionary *)info {
    [self sendMessageName:msg userInfo:info];
    return nil;
}
- (void)handleNotificationName:(NSString *)name userInfo:(NSDictionary *)userInfo {
    if (!userInfo) return;
    NSString *msg = userInfo[@"msgName"];
    if (!msg) return;
    NSString *key = [NSString stringWithFormat:@"%@~%@", self.clientServiceName, msg];
    NSArray *t = self.registeredTargets[key];
    if (!t || t.count < 2) return;
    id target = t[0];
    SEL sel = NSSelectorFromString(t[1]);
    NSString *purified = [self purifyClientName:key];
    NSDictionary *arg = userInfo[msg];
    if (!arg) arg = @{};
    if ([target respondsToSelector:sel]) {
        ((void (*)(id, SEL, id, id))objc_msgSend)(target, sel, purified, arg);
    }
}
@end
