package;

import kha.Framebuffer;
import kha.Image;
import kha.System;
import kha.Scheduler;
import kha.input.Mouse;
import kha.math.FastVector4;
import kha.graphics4.TextureFormat;
import kha.graphics4.Graphics;
import kha.graphics4.VertexBuffer;
import kha.graphics4.IndexBuffer;
import kha.graphics4.PipelineState;
import kha.graphics4.VertexStructure;
import kha.graphics4.VertexData;
import kha.graphics4.Usage;
import kha.graphics4.TextureUnit;
import kha.graphics4.ConstantLocation;

class Empty {

	static inline var iChannel0W = 14;
	static inline var iChannel0H = 14;

	var iChannel0:Image;
	var backBuffer:Image;
	var pipe:PipelineState;
	var pipeBuffer:PipelineState;
	var screenAlignedVB:VertexBuffer = null;
	var screenAlignedIB:IndexBuffer = null;

	var iGlobalTime:Float = 0;
	var iFrame:Int = 0;
	var iMouse:FastVector4 = new FastVector4(0, 0, 0, 0);

	var lastTime:Float;

	public function new() {
		iChannel0 = Image.createRenderTarget(iChannel0W, iChannel0H, TextureFormat.RGBA128);
		backBuffer = Image.createRenderTarget(512, 512, TextureFormat.RGBA32);

		var structure = new VertexStructure();
        structure.add("pos", VertexData.Float2);
        var structureLength = 2;

		var data = [-1.0, -1.0, 1.0, -1.0, 1.0, 1.0, -1.0, 1.0];
		var indices = [0, 1, 2, 0, 2, 3];

		screenAlignedVB = new VertexBuffer(Std.int(data.length / structureLength),
										   structure, Usage.StaticUsage);
		
		var vertices = screenAlignedVB.lock();
		for (i in 0...vertices.length) {
			vertices.set(i, data[i]);
		}
		screenAlignedVB.unlock();

		screenAlignedIB = new IndexBuffer(indices.length, Usage.StaticUsage);
		var id = screenAlignedIB.lock();
		for (i in 0...id.length) {
			id[i] = indices[i];
		}
		screenAlignedIB.unlock();

		pipe = new PipelineState();
		pipe.inputLayout = [structure];
		pipe.fragmentShader = kha.Shaders.image_frag;
		pipe.vertexShader = kha.Shaders.quad_vert;
		pipe.compile();

		pipeBuffer = new PipelineState();
		pipeBuffer.inputLayout = [structure];
		pipeBuffer.fragmentShader = kha.Shaders.buffer_frag;
		pipeBuffer.vertexShader = kha.Shaders.quad_vert;
		pipeBuffer.compile();

		lastTime = Scheduler.time();

		Mouse.get().notify(onMouseDown, onMouseUp, onMouseMove, null);
	}
	
	public function render(framebuffer:Framebuffer) {
		// Buffer
		var g = iChannel0.g4;
		g.begin();
		g.clear();

		g.setPipeline(pipeBuffer);
		setConstants(g, pipeBuffer);

		g.setVertexBuffer(screenAlignedVB);
		g.setIndexBuffer(screenAlignedIB);
		g.drawIndexedVertices();

		g.end();

		// Image
		var g = backBuffer.g4;
		g.begin();

		g.setPipeline(pipe);
		setConstants(g, pipe);

		g.setVertexBuffer(screenAlignedVB);
		g.setIndexBuffer(screenAlignedIB);
		g.drawIndexedVertices();

		g.end();

		var g = framebuffer.g2;
		g.begin();
		g.drawScaledImage(backBuffer, 0, 512, 512, -512);
		g.end();

		// Update
		iFrame++;
		iGlobalTime += Scheduler.time() - lastTime;
  		lastTime = Scheduler.time();
	}

	function setConstants(g:Graphics, p:PipelineState) {
		// Just for simplicity, no need to get locations every frame
		var tu = p.getTextureUnit("iChannel0");
		//g.setTextureParameters(tu, kha.graphics4.TextureAddressing.Repeat, kha.graphics4.TextureAddressing.Repeat, kha.graphics4.TextureFilter.AnisotropicFilter, kha.graphics4.TextureFilter.AnisotropicFilter, kha.graphics4.MipMapFilter.NoMipFilter);
		g.setTexture(tu, iChannel0);
		g.setFloat3(p.getConstantLocation("iChannelResolution0"), iChannel0.realWidth, iChannel0.realHeight, 0);
		g.setFloat(p.getConstantLocation("iGlobalTime"), iGlobalTime);
		g.setInt(p.getConstantLocation("iFrame"), iFrame);
		g.setFloat3(p.getConstantLocation("iResolution"), backBuffer.realWidth, backBuffer.realHeight, 0);
		g.setVector4(p.getConstantLocation("iMouse"), iMouse);
	}

	function onMouseDown(button:Int, x:Int, y:Int) {
		iMouse.w = 1.0;
	}

	function onMouseUp(button:Int, x:Int, y:Int) {
		iMouse.w = 0.0;
	}

	function onMouseMove(x:Int, y:Int, movementX:Int, movementY:Int) {
		iMouse.x = x;
		iMouse.y = y;
	}
}
