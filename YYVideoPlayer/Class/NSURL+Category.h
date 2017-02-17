
#import <Foundation/Foundation.h>

@interface NSURL (Category)

/**
 *  自定义scheme
 */
- (NSURL *)customSchemeURL;

/**
 *  还原scheme
 */
- (NSURL *)originalSchemeURL;

@end
