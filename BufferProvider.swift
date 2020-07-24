import Cocoa
import simd
import Accelerate

struct Uniform {
  var scale: Float = 1
  var translation: (x: Float, y: Float) = (0, 0)
  var maxNumberOfiterations: Float = 500
  var aspectRatio: Float = 1
  var z: (z1: (r: Float, im: Float), z2: (r: Float, im: Float), z3: (r: Float, im: Float)) = ((0.0, 0.0), (1.0, 0.0), (0.5, 0.5))
  //var z: (z1: (r: Float, im: Float), z2: (r: Float, im: Float), z3: (r: Float, im: Float)) = ((0.0, 0.0), (.infinity, 0.0), (0.5, 0.5))

  fileprivate var raw: [Float] {
    return [scale, translation.x, translation.y, maxNumberOfiterations, aspectRatio, z.z1.r, z.z1.im, z.z2.r, z.z2.im, z.z3.r, z.z3.im, 0, 0, 0]
  }
  
  static var size = MemoryLayout<Float>.size * 14
}


/// I use class, to have deinit() for semaphores cleanup
class BufferProvider {
  
  // General values
  static let floatSize = MemoryLayout<Float>.size
  static var bufferSize = Uniform.size
  
  // Reuse related
  fileprivate(set) var indexOfAvaliableBuffer = 0
  fileprivate(set) var numberOfInflightBuffers: Int
  fileprivate var buffers:[MTLBuffer]
  fileprivate(set) var avaliableResourcesSemaphore:DispatchSemaphore
  
  init(inFlightBuffers: Int, device: MTLDevice) {
    
    avaliableResourcesSemaphore = DispatchSemaphore(value: inFlightBuffers)
    
    numberOfInflightBuffers = inFlightBuffers
    buffers = [MTLBuffer]()
    
    for _ in 0 ..< inFlightBuffers {
      if let buffer = device.makeBuffer(length: BufferProvider.bufferSize, options: MTLResourceOptions()) {
        buffer.label = "Uniform buffer"
        buffers.append(buffer)
      }
    }
  }
  
  deinit{
    for _ in 0...numberOfInflightBuffers{
      avaliableResourcesSemaphore.signal()
    }
  }
  
  func nextBufferWithData(_ uniform: Uniform) -> MTLBuffer {
    
    // Cycle through buffers
    let uniformBuffer = self.buffers[indexOfAvaliableBuffer]
    indexOfAvaliableBuffer += 1
    if indexOfAvaliableBuffer == numberOfInflightBuffers {
      indexOfAvaliableBuffer = 0
    }
    
    memcpy(uniformBuffer.contents(), uniform.raw, Uniform.size)
    return uniformBuffer
  }
  
}
