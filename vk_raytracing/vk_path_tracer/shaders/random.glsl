



uint pcg_hash(inout uint seed){
	seed = seed * 747796405u + 2891336453u;
	uint word = ((seed >> ((seed >> 28u) + 4u)) ^ seed) * 277803737u;
	return (word >> 22u) ^ word;
}

//// Generate a random float in [0, 1)
float rand(inout uint seed) {
	return float(pcg_hash(seed)) / 4294967295.0f;
}

// Generate a random unsigned int from two unsigned int values, using 16 pairs
// of rounds of the Tiny Encryption Algorithm. See Zafar, Olano, and Curtis,
// "GPU Random Numbers via the Tiny Encryption Algorithm"
uint InitRandomSeed(uint val0, uint val1) {
  uint v0 = val0;
  uint v1 = val1;
  uint s0 = 0;

  for(uint n = 0; n < 16; n++)
  {
    s0 += 0x9e3779b9;
    v0 += ((v1 << 4) + 0xa341316c) ^ (v1 + s0) ^ ((v1 >> 5) + 0xc8013ea4);
    v1 += ((v0 << 4) + 0xad90777d) ^ (v0 + s0) ^ ((v0 >> 5) + 0x7e95761e);
  }

  return v0;
}

vec2 randomGaussian(inout uint rngState) {
  const float k_pi = 3.14159265;

  // Almost uniform in (0,1] - make sure the value is never 0:
  const float u1    = max(1e-38, rand(rngState));
  const float u2    = rand(rngState);  // In [0, 1]
  const float r     = sqrt(-2.0 * log(u1));
  const float theta = 2 * k_pi * u2;  // Random in [0, 2pi]
  return r * vec2(cos(theta), sin(theta));
}

vec2 RandomInUnitDisk(inout uint seed) {
	for (;;) {
		const vec2 p = 2 * vec2(rand(seed), rand(seed)) - 1;
		if (dot(p, p) < 1) {
			return normalize(p);
		}
	}
}

vec3 RandomInUnitSphere(inout uint seed) {
	for (;;) {
		const vec3 p = 2 * vec3(rand(seed), rand(seed), rand(seed)) - 1;
		if (dot(p, p) < 1) {
			return normalize(p);
		}
	}
}

vec3 RandomInUnitSemiSphere(inout uint seed, vec3 normal) {
    return normalize(RandomInUnitSphere(seed) + normal);
}

vec3 randomBarycentricPointInTriangle(inout uint seed, vec3 A, vec3 B, vec3 C) {
    float r1 = rand(seed);  // Supone que tienes una función rand() que retorna un valor entre 0 y 1
    float r2 = rand(seed);

    // Ajustar r1 y r2 si la suma excede 1
    if (r1 + r2 > 1.0) {
        r1 = 1.0 - r1;
        r2 = 1.0 - r2;
    }

    // Coordenadas baricéntricas
    float a = 1.0 - r1 - r2;
    float b = r1;
    float c = r2;

    // Punto dentro del triángulo
    return vec3(a,b,c);

//    return a * A.pos + b * B.pos + c * C.pos;
}