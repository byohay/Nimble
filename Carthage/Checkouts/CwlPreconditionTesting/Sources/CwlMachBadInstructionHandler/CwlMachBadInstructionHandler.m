//
//  CwlMachBadExceptionHandler.m
//  CwlPreconditionTesting
//
//  Created by Matt Gallagher on 2016/01/10.
//  Copyright © 2016 Matt Gallagher ( https://www.cocoawithlove.com ). All rights reserved.
//
//  Permission to use, copy, modify, and/or distribute this software for any
//  purpose with or without fee is hereby granted, provided that the above
//  copyright notice and this permission notice appear in all copies.
//
//  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
//  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
//  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
//  SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
//  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
//  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
//  IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
//

#ifdef __APPLE__
#import "TargetConditionals.h"
#if TARGET_OS_OSX || TARGET_OS_IOS

#import "mach_excServer.h"
#import "CwlMachBadInstructionHandler.h"

#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>


@protocol BadInstructionReply <NSObject>
+(NSNumber *)receiveReply:(NSValue *)value;
@end

/// A basic function that receives callbacks from mach_exc_server and relays them to the Swift implemented BadInstructionException.catch_mach_exception_raise_state.
kern_return_t catch_mach_exception_raise_state(mach_port_t exception_port, exception_type_t exception, const mach_exception_data_t code, mach_msg_type_number_t codeCnt, int *flavor, const thread_state_t old_state, mach_msg_type_number_t old_stateCnt, thread_state_t new_state, mach_msg_type_number_t *new_stateCnt) {
	bad_instruction_exception_reply_t reply = { exception_port, exception, code, codeCnt, flavor, old_state, old_stateCnt, new_state, new_stateCnt };
	Class badInstructionClass = NSClassFromString(@"BadInstructionException");
	NSValue *value = [NSValue valueWithBytes: &reply objCType: @encode(bad_instruction_exception_reply_t)];
	return [[badInstructionClass performSelector: @selector(receiveReply:) withObject: value] intValue];
}

// The mach port should be configured so that this function is never used.
kern_return_t catch_mach_exception_raise(mach_port_t exception_port, mach_port_t thread, mach_port_t task, exception_type_t exception, mach_exception_data_t code, mach_msg_type_number_t codeCnt) {
	assert(false);
	return KERN_FAILURE;
}

// The mach port should be configured so that this function is never used.
kern_return_t catch_mach_exception_raise_state_identity(mach_port_t exception_port, mach_port_t thread, mach_port_t task, exception_type_t exception, mach_exception_data_t code, mach_msg_type_number_t codeCnt, int *flavor, thread_state_t old_state, mach_msg_type_number_t old_stateCnt, thread_state_t new_state, mach_msg_type_number_t *new_stateCnt) {
	assert(false);
	return KERN_FAILURE;
}

static NSDictionary<NSString *, NSNumber *> * LTGetImageNameToSlide() {
  NSMutableDictionary<NSString *, NSNumber *> *imageNameToSlide;
  for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
    imageNameToSlide[[NSString stringWithUTF8String:_dyld_get_image_name(i)]] = @(_dyld_get_image_vmaddr_slide(i));
  }
    
  return imageNameToSlide;
}

typedef struct {
  /// Constructs a new segment info. Used for emplacing the struct directly into a vector.
//  LTSegmentInfo(uint64_t start, uint64_t length) : start(start), length(length) {};

  /// Start of the range.
  uint64_t start;

  /// Length of the range.
  uint64_t length;
} LTSegmentInfo;

static bool LTIsMachHeader64Bit(const struct mach_header *header) {
  return header->magic == MH_MAGIC_64 || header->magic == MH_CIGAM_64;
}

static uintptr_t LTGetPostHeaderPointer(const struct mach_header *header) {
  return (uintptr_t)header + (LTIsMachHeader64Bit(header) ? sizeof(struct mach_header_64) :
                              sizeof(struct mach_header));
}

NSArray<NSValue *> *LTGetSegments() {
  NSMutableArray<NSValue *> *segments = [NSMutableArray array];

  NSDictionary<NSString *, NSNumber *> *slides = LTGetImageNameToSlide();

  for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
    NSString *imageName = [NSString stringWithUTF8String:_dyld_get_image_name(i)];

    const struct mach_header *header = (const struct mach_header *)_dyld_get_image_header(i);
    uintptr_t pointer = LTGetPostHeaderPointer(header);

    for (uint32_t j = 0; j < header->ncmds; ++j) {
      const struct load_command * loadCommand = (const struct load_command *)pointer;
      if (loadCommand->cmd == LC_SEGMENT) {
        struct segment_command *segmentCommand = (struct segment_command *)loadCommand;
      
          LTSegmentInfo segmentInfo;
          segmentInfo.start = segmentCommand->vmaddr + slides[imageName].unsignedIntValue;
          segmentInfo.length = segmentCommand->vmsize;
          
        NSValue *value = [NSValue valueWithBytes:&segmentInfo objCType:@encode(LTSegmentInfo)];
          
          [segments addObject:value];
      } else if (loadCommand->cmd == LC_SEGMENT_64) {
          struct segment_command_64 *segmentCommand = (struct segment_command_64 *)loadCommand;
          LTSegmentInfo segmentInfo;
          segmentInfo.start = segmentCommand->vmaddr + slides[imageName].unsignedIntValue;
          segmentInfo.length = segmentCommand->vmsize;
          
        NSValue *value = [NSValue valueWithBytes:&segmentInfo objCType:@encode(LTSegmentInfo)];
          
          [segments addObject:value];
      }

      pointer += loadCommand->cmdsize;
    }
  }

  return segments;
}

BOOL isExceptionComingFromSwift(__uint64_t address) {
    Dl_info info;
    dladdr((const void *)address, &info);
    
    return strcmp(info.dli_fname, "/usr/lib/swift/libswiftCore.dylib") == 0;
}

#endif /* TARGET_OS_OSX || TARGET_OS_IOS */
#endif /* __APPLE__ */
