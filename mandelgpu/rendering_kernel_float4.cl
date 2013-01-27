/*
Copyright (c) 2009 David Bucciarelli (davibu@interfree.it)

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

static int colormap(const int maxIterations, int i) {
	if (i == maxIterations)
		return 0;
	else {
		i = i % 512;
		if (i > 255)
			return 511 - i;
		else
			return i;
	}
}

__kernel void mandelGPU(
		__global int *pixels,
		const int width,
		const int height,
		const float scale,
		const float offsetX,
		const float offsetY,
		const int maxIterations
		) {
	const int gid = get_global_id(0);
	const int gid4 = 4 * gid;
	// Szaq's patch for NVIDIA OpenCL and Windows
	const float4 maxSize = (float4)max(width, height);
	const float4 kx = (scale / 2.f) * width;
	const float4 ky = (scale / 2.f) * height;

	const uint4 tid =  (uint4)(gid4, gid4 + 1, gid4 + 2, gid4 +3);
	// Szaq's patch for NVIDIA OpenCL and Windows
	const uint4 width4 = (uint4)width;
	const uint4 screenX = tid % width4;
	const uint4 screenY = tid / width4;

	// Check if we have something to do
	if ((screenY.s0 >= height) ||
			(screenY.s1 >= height) ||
			(screenY.s2 >= height) ||
			(screenY.s3 >= height))
		return;

	const float4 fscreenX = convert_float4(screenX);
	const float4 fscreenY = convert_float4(screenY);

	const float4 x0 = ((fscreenX * ((float4)scale)) - kx) / maxSize + (float4)offsetX;
	const float4 y0 = ((fscreenY * ((float4)scale)) - ky) / maxSize + (float4)offsetY;

	float4 x = x0;
	float4 y = y0;
	float4 x2 = x * x;
	float4 y2 = y * y;

	const float4 two = 2.f;
	int4 iter = 0;
	const int4 maxIterations4 = maxIterations;
	const int4 one = (int4)( 1, 1, 1, 1);
	for (;;) {
		y = ((float4)2.f) * x * y + y0;
		x = x2 - y2 + x0;

		x2 = x * x;
		y2 = y * y;

		const float4 x2y2 = x2 + y2;
		const int4 notEscaped = (x2y2 <= (float4)4.f);
		const int4 notMaxIter = (iter < maxIterations4);

		// It looks like ATI's compiler is bugged and doesn't accept: notEscaped && notMaxIter;
		// And for some unknown reason (notEscaped & notMaxIter) is very very slow
		//const int4 notHaveToExit = (notEscaped & notMaxIter);
		const int4 notHaveToExit = (int4)(notEscaped.s0 & notMaxIter.s0,
					notEscaped.s1 & notMaxIter.s1,
				notEscaped.s2 & notMaxIter.s2,
				notEscaped.s3 & notMaxIter.s3);
		if (!any(notHaveToExit))
			break;

		iter += (one & notHaveToExit);
	}

	const int s0 = colormap(maxIterations, iter.s0);
	const int s1 = colormap(maxIterations, iter.s1);
	const int s2 = colormap(maxIterations, iter.s2);
	const int s3 = colormap(maxIterations, iter.s3);

	pixels[gid] = s0 | (s1 << 8) | (s2 << 16) | (s3 << 24);
}
