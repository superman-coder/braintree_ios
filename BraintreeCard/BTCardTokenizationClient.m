#import "BTErrors.h"
#import "BTTokenizationService.h"
#import "BTCardTokenizationClient.h"
#import "BTTokenizedCard_Internal.h"
#import "BTHTTP.h"
#import "BTJSON.h"
#import "BTClientMetadata.h"
#import "BTAPIClient_Internal.h"
#import "BTCardTokenizationRequest_Internal.h"

NSString *const BTCardTokenizationClientErrorDomain = @"com.braintreepayments.BTCardTokenizationClientErrorDomain";

@interface BTCardTokenizationClient ()
@property (nonatomic, strong, readwrite) BTAPIClient *apiClient;
@end

@implementation BTCardTokenizationClient

+ (void)load {
    if (self == [BTCardTokenizationClient class]) {
        [[BTTokenizationService sharedService] registerType:@"Card" withTokenizationBlock:^(BTAPIClient *apiClient, NSDictionary *options, void (^completionBlock)(id<BTTokenized> tokenization, NSError *error)) {
            BTCardTokenizationClient *client = [[BTCardTokenizationClient alloc] initWithAPIClient:apiClient];
            BTCardTokenizationRequest *request = [[BTCardTokenizationRequest alloc] initWithParameters:options];
            [client tokenizeCard:request completion:completionBlock];
        }];
    }
}

- (instancetype)initWithAPIClient:(BTAPIClient *)apiClient {
    if (self = [super init]) {
        // TODO: do we need to use copyWithSource:integration: here?
        self.apiClient = apiClient;
    }
    return self;
}

- (instancetype)init {
    return nil;
}

- (void)tokenizeCard:(BTCardTokenizationRequest *)card
          completion:(void (^)(BTTokenizedCard *tokenizedCard, NSError *error))completionBlock {

    [self.apiClient POST:@"v1/payment_methods/credit_cards"
              parameters:@{ @"credit_card": card.parameters }
              completion:^(BTJSON *body, __unused NSHTTPURLResponse *response, NSError *error) {
                  if (error != nil) {

                      // Check if the error is a card validation error, and provide add'l error info
                      // about the validation errors in the userInfo
                      NSHTTPURLResponse *response = error.userInfo[BTHTTPURLResponseKey];
                      if (response.statusCode == 422) {
                          BTJSON *jsonResponse = error.userInfo[BTHTTPJSONResponseBodyKey];
                          NSDictionary *userInfo = jsonResponse.asDictionary ? @{ BTCustomerInputBraintreeValidationErrorsKey : jsonResponse.asDictionary } : @{};
                          NSError *validationError = [NSError errorWithDomain:BTCardTokenizationClientErrorDomain
                                                                         code:BTErrorCustomerInputInvalid
                                                                     userInfo:userInfo];
                          completionBlock(nil, validationError);
                      } else {
                          completionBlock(nil, error);
                      }

                      return;
                  }

                  BTJSON *creditCard = body[@"creditCards"][0];
                  if (creditCard.isError) {
                      completionBlock(nil, creditCard.asError);
                  } else {
                      completionBlock([BTTokenizedCard cardWithJSON:creditCard], nil);
                  }
              }];
}

@end