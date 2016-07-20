// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "WaterfallViewController.h"

#include <gtest/gtest.h>
#include <memory>

#include "escher/renderer.h"
#include "examples/waterfall/scenes/app_test_scene.h"
#include "examples/waterfall/scenes/material_stage.h"
#include "examples/waterfall/scenes/shadow_test_scene.h"

constexpr bool kDrawShadowTestScene = false;

@interface WaterfallViewController () {
  escher::Stage stage_;
  std::unique_ptr<escher::Renderer> renderer_;
  glm::vec2 focus_;
  AppTestScene app_test_scene_;
  ShadowTestScene shadow_test_scene_;
}

@property(strong, nonatomic) EAGLContext* context;

@end

@implementation WaterfallViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
  self.preferredFramesPerSecond = 60;

  if (!self.context) {
    NSLog(@"Failed to create ES context");
  }

  GLKView* view = (GLKView*)self.view;
  view.context = self.context;
  view.drawableDepthFormat = GLKViewDrawableDepthFormat24;

  [EAGLContext setCurrentContext:self.context];

  app_test_scene_.InitGL();
  InitStageForMaterial(&stage_);
  renderer_.reset(new escher::Renderer());

  if (!renderer_->Init()) {
    NSLog(@"Failed to initialize renderer");
  }

  CGSize size = self.view.bounds.size;
  focus_ = glm::vec2(size.width / 2.0f, size.height / 2.0f);

  [self.runTestsButton setBackgroundColor: [UIColor whiteColor]];

  [self update];
}

- (void)dealloc {
  [EAGLContext setCurrentContext:self.context];
  renderer_.reset();
  [EAGLContext setCurrentContext:nil];
}

- (BOOL)prefersStatusBarHidden {
  return YES;
}

- (void)update {
  CGFloat contentScaleFactor = self.view.contentScaleFactor;
  CGSize size = self.view.bounds.size;

  // iOS GLES 2.0 doesn't support mipmapping of NPOT textures, so make the
  // stage width/height a power-of-two.
  CGFloat width = 1.0;
  CGFloat height = 1.0;
  constexpr int kEnoughForGigapixelDisplays = 20;
  for (int i = 0; i < kEnoughForGigapixelDisplays; ++i) {
    if (width * 2 <= size.width) width *= 2.0;
    if (height * 2 <= size.height) height *= 2.0;
  }

  stage_.Resize(escher::SizeI(width, height),
                contentScaleFactor,
                escher::SizeI(0, size.height - height));
}

- (void)glkView:(GLKView*)view drawInRect:(CGRect)rect {
  // TODO(abarth): There must be a better way to initialize this information.
  if (!renderer_->front_frame_buffer_id()) {
    GLint fbo = 0;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &fbo);
    renderer_->set_front_frame_buffer_id(fbo);
  }

  escher::Model model;
  if (kDrawShadowTestScene) {
    model = shadow_test_scene_.GetModel(stage_.viewing_volume());
  } else {
    model = app_test_scene_.GetModel(stage_.viewing_volume(), focus_);
  }
  model.set_blur_plane_height(self.blurPlaneHeightSlider.value);
  renderer_->Render(stage_, model);
}

- (void)touchesMoved:(NSSet*)touches withEvent:(UIEvent*)event {
    for (UITouch* touch in touches) {
        CGPoint windowCoordinates = [touch locationInView:nil];
        focus_ = glm::vec2(windowCoordinates.x, windowCoordinates.y);
    }
    [self.view setNeedsDisplay];
}

- (IBAction)handleButtonClick:(id)sender {
  if (sender == self.runTestsButton) {
    static bool first_run = true;
    if (first_run) {
      first_run = false;
      int argc = 1;
      char* argv[1];
      argv[0] = const_cast<char*>("Waterfall");
      testing::InitGoogleTest(&argc, argv);
    }
    int error = RUN_ALL_TESTS();
    if (error) {
      NSLog(@"Some Tests Failed");
      [self.runTestsButton setBackgroundColor: [UIColor redColor]];
    } else {
      NSLog(@"All Tests Passed");
      [self.runTestsButton setBackgroundColor: [UIColor greenColor]];
    }
  } else {
    NSLog(@"Unexpected button click");
  }
}

@end
