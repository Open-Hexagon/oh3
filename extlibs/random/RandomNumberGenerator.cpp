// Copyright (c) 2013-2020 Vittorio Romeo
// License: Academic Free License ("AFL") v. 3.0
// AFL License page: https://opensource.org/licenses/AFL-3.0

#include "RandomNumberGenerator.hpp"

#include <random>

#include "PCG/PCG.hpp"

random_number_generator::random_number_generator(const seed_type seed) noexcept
    : _seed{seed}, _rng{seed} {
	advance(1);
}

[[nodiscard]] random_number_generator::seed_type random_number_generator::seed()
    const noexcept {
	return _seed;
}

[[nodiscard]] random_number_generator initializeRng() {
	thread_local pcg32_fast seed_rng = [] {
		pcg_extras::seed_seq_from<std::random_device> seed_source;
		return pcg32_fast{seed_source};
	}();
	return random_number_generator{seed_rng()};
}

auto rng = initializeRng();

#ifdef __cplusplus
extern "C" {
#endif

void init_rng() { rng = initializeRng(); }

void set_seed(unsigned long long seed) { rng = random_number_generator{seed}; }
unsigned long long get_seed() { return rng.seed(); }

int get_int(const int min, const int max) { return rng.get_int(min, max); }

float get_real(const float min, const float max) {
	return rng.get_real(min, max);
}

void advance(const float v) {
	const auto fixup =
	    [](const float x) -> random_number_generator::state_type {
		return x < 0.f ? -x : x;
	};
	rng.advance(fixup(v));
}

#ifdef __cplusplus
}
#endif
