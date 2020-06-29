// Copyright (c) 2020 Lightricks. All rights reserved.
// Created by Ben Yohay.

NS_ASSUME_NONNULL_BEGIN

@interface CwlBadInstructionException : NSException

- (NSNumber *)receiveReply:(NSValue *)value;

@end

NS_ASSUME_NONNULL_END
