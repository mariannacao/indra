//
//  ViewController.swift
//  Mandelbrot
//
//  Created by Andriy K. on 2/4/16.
//  Copyright © 2016 Andriy K. All rights reserved.
//

import Cocoa
import MetalKit

class MandelbrotViewController: NSViewController {
      
  // Metal related properties
  fileprivate var device: MTLDevice!
  fileprivate var commandQ: MTLCommandQueue!
  fileprivate var pipelineState: MTLRenderPipelineState!
  fileprivate var depthStencilState: MTLDepthStencilState!
  fileprivate var paletteTexture: MTLTexture!
  fileprivate var samplerState: MTLSamplerState!
  fileprivate var uniformBufferProvider: BufferProvider!
  fileprivate var mandelbrotSceneUniform = Uniform()
  
  // Flags to control draw calls
  fileprivate var needsRedraw = true
  var forceAlwaysDraw = false
  
  // Object to render
  fileprivate var square: Square!
  
  
  // Handles to move and zoom
  fileprivate var oldZoom: Float = 1.0
  fileprivate var shiftX: Float = 0
  fileprivate var shiftY: Float = 0
  
  
  @IBOutlet var metalView: MTKView! {
    didSet {
      metalView.device = device
      metalView.delegate = self
      metalView.preferredFramesPerSecond = 60
      metalView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
    }
  }
  
  
  func setupMetal() {
    device = MTLCreateSystemDefaultDevice()
    metalView.device = device
    commandQ = device.makeCommandQueue()
    square = Square(device: device)
    
    let textureLoader = MTKTextureLoader(device: device)
    let path = Bundle.main.path(forResource: "pal", ofType: "png")!
    let data = try! Data(contentsOf: URL(fileURLWithPath: path))
    
    paletteTexture = try! textureLoader.newTexture(data: data, options: nil)
    samplerState = square.defaultSampler(device)
    uniformBufferProvider = BufferProvider(inFlightBuffers: 3, device: device)
  }
  
  func myVertexDescriptor() -> MTLVertexDescriptor {
    let metalVertexDescriptor = MTLVertexDescriptor()
    if let attribute = metalVertexDescriptor.attributes[0] {
      attribute.format = MTLVertexFormat.float3
      attribute.offset = 0
      attribute.bufferIndex = 0
    }
    if let layout = metalVertexDescriptor.layouts[0] {  // this zero correspons to  buffer index
      layout.stride = MemoryLayout<Float>.size * (3)
    }
    return metalVertexDescriptor
  }
  
}

var mode = false

// MARK: - Compiled states
extension MandelbrotViewController {
  
  /// Compile vertex, fragment shaders and vertex descriptor into pipeline state object
  func compiledPipelineStateFrom(vertexShader: MTLFunction,
                                 fragmentShader: MTLFunction, vertexDescriptor: MTLVertexDescriptor) -> MTLRenderPipelineState? {
    let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
    pipelineStateDescriptor.vertexDescriptor = vertexDescriptor
    pipelineStateDescriptor.vertexFunction = vertexShader
    pipelineStateDescriptor.fragmentFunction = fragmentShader
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
    pipelineStateDescriptor.depthAttachmentPixelFormat = metalView.depthStencilPixelFormat
    pipelineStateDescriptor.stencilAttachmentPixelFormat = metalView.depthStencilPixelFormat
    
    let compiledState = try! device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
    return compiledState
  }
  
  /// Compile depth/stencil descriptor into state object
  /// We don't really need depth check for this example but it's a good thing to have
  func compiledDepthState() -> MTLDepthStencilState {
    let depthStencilDesc = MTLDepthStencilDescriptor()
    depthStencilDesc.depthCompareFunction = MTLCompareFunction.less
    depthStencilDesc.isDepthWriteEnabled = true
    
    return device.makeDepthStencilState(descriptor: depthStencilDesc)!
  }
  
}

// MARK: - Zoom & Move
extension MandelbrotViewController {
        
    /*override func mouseDown(with theEvent: NSEvent) {
        super.mouseDown(with: theEvent);
        //print(theEvent.locationInWindow, self.view.bounds.width, self.view.bounds.height);
        
        mandelbrotSceneUniform.z.z3.r = (Float((theEvent.locationInWindow.x)/self.view.bounds.width-0.5)*2.0 * mandelbrotSceneUniform.aspectRatio) * mandelbrotSceneUniform.scale - mandelbrotSceneUniform.translation.x;
        mandelbrotSceneUniform.z.z3.im = Float(theEvent.locationInWindow.y/self.view.bounds.height-0.5)*2.0 * mandelbrotSceneUniform.scale - mandelbrotSceneUniform.translation.y;
        
        needsRedraw = true
    }*/
    
    override func mouseDragged(with theEvent: NSEvent) {
        super.mouseDragged(with: theEvent);
        
        if(mode){
            //print(theEvent.locationInWindow, self.view.bounds.width, self.view.bounds.height);
            
            mandelbrotSceneUniform.z.z3.r = (Float((theEvent.locationInWindow.x)/self.view.bounds.width-0.5)*2.0 * mandelbrotSceneUniform.aspectRatio) * mandelbrotSceneUniform.scale - mandelbrotSceneUniform.translation.x;
            mandelbrotSceneUniform.z.z3.im = Float(theEvent.locationInWindow.y/self.view.bounds.height-0.5)*2.0 * mandelbrotSceneUniform.scale - mandelbrotSceneUniform.translation.y;
        }
        else{
            let xDelta = Float(theEvent.deltaX/self.view.bounds.width)
            let yDelta = Float(theEvent.deltaY/self.view.bounds.height)
            
            shiftX += xDelta / oldZoom
            shiftY -= yDelta / oldZoom
            
            mandelbrotSceneUniform.translation = (shiftX, shiftY)
        }
        needsRedraw = true
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()

        NSEvent.addLocalMonitorForEvents(matching: NSEvent.EventTypeMask.keyDown, handler: myKeyDownEvent)
        
        setupMetal()
        guard let defaultLibrary = device.makeDefaultLibrary() else {
          assert(false)
          return
        }
        let vertexProgram = defaultLibrary.makeFunction(name: "vertexShader")!
        let fragmentProgram = defaultLibrary.makeFunction(name: "fragmentShader")!
        let metalVertexDescriptor = myVertexDescriptor()
        
        pipelineState = compiledPipelineStateFrom(vertexShader: vertexProgram, fragmentShader: fragmentProgram, vertexDescriptor: metalVertexDescriptor)
        depthStencilState = compiledDepthState()
    }

    func myKeyDownEvent(event: NSEvent) -> NSEvent
    {
        switch event.keyCode {
        case 12: //q
            mandelbrotSceneUniform.z.z2.r = 1.0
            mandelbrotSceneUniform.z.z2.im = 0.0
            needsRedraw = true
        case 13: //w
            mandelbrotSceneUniform.z.z2.r = .infinity
            mandelbrotSceneUniform.z.z2.im = 0.0
            needsRedraw = true
        case 0: //a
            mode = true
        case 1: //s
            mode = false
        default:
            print(event.keyCode)
        }
        
        return event
    }

  
  @IBAction func zoom(_ sender: NSMagnificationGestureRecognizer) {
    print("zooming")
    let zoom = Float(sender.magnification)
    let zoomMultiplier = Float(max(Int(oldZoom / 100),1)) // to speed up zooming the deeper you go
    
    oldZoom += zoom * zoomMultiplier
    oldZoom = max(1, oldZoom)
    mandelbrotSceneUniform.scale = 1 / oldZoom
    needsRedraw = true
  }
}

extension MandelbrotViewController: MTKViewDelegate {
  
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    mandelbrotSceneUniform.aspectRatio = Float(size.width / size.height)
    needsRedraw = true
  }
  
  func draw(in view: MTKView) {
    
    guard (needsRedraw == true || forceAlwaysDraw == true) else { return }
    guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
    guard let drawable = view.currentDrawable else { return }
    
    renderPassDescriptor.colorAttachments[0].loadAction = .clear
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 1.0)
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store
    renderPassDescriptor.colorAttachments[0].texture = drawable.texture
    
    guard let commandBuffer = commandQ.makeCommandBuffer(),
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
        return
    }
    
    renderEncoder.setRenderPipelineState(pipelineState)
    renderEncoder.setDepthStencilState(depthStencilState)
    renderEncoder.setCullMode(MTLCullMode.none)
    
    if let squareBuffer = square?.vertexBuffer {
        renderEncoder.setVertexBuffer(squareBuffer, offset: 0, index: 0)
    }
    
    let uniformBuffer = uniformBufferProvider.nextBufferWithData(mandelbrotSceneUniform)
    renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
    renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
    
    renderEncoder.setFragmentTexture(paletteTexture, index: 0)
    renderEncoder.setFragmentSamplerState(samplerState, index: 0)
    
    renderEncoder.drawPrimitives(type: MTLPrimitiveType.triangle, vertexStart: 0, vertexCount: 6)
    
    renderEncoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
    
    needsRedraw = false
  }
  
}

