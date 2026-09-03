//! Deterministic gameplay world shared by the server, simulator, and client prediction.

pub const TICKS_PER_SECOND: u64 = 60;
pub const UNITS_PER_METER: i64 = 1_000;

const INPUT_MAX: i64 = i16::MAX as i64;
const MOVEMENT_DENOMINATOR: i64 = INPUT_MAX * TICKS_PER_SECOND as i64;

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct FixedVec2 {
    pub x: i64,
    pub y: i64,
}

impl FixedVec2 {
    #[must_use]
    pub const fn new(x: i64, y: i64) -> Self {
        Self { x, y }
    }
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct MovementIntent {
    x: i16,
    y: i16,
}

impl MovementIntent {
    pub const IDLE: Self = Self { x: 0, y: 0 };
    pub const RIGHT: Self = Self { x: i16::MAX, y: 0 };

    #[must_use]
    pub fn new(x: i16, y: i16) -> Self {
        let (clamped_x, clamped_y) = clamp_to_unit_circle(i64::from(x), i64::from(y));
        Self {
            x: clamped_x as i16,
            y: clamped_y as i16,
        }
    }

    #[must_use]
    pub const fn x(self) -> i16 {
        self.x
    }

    #[must_use]
    pub const fn y(self) -> i16 {
        self.y
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct WorldConfig {
    pub map_half_extent: FixedVec2,
    pub character_half_extent: i64,
    pub movement_speed_per_second: i64,
    pub spawn: FixedVec2,
}

impl WorldConfig {
    #[must_use]
    pub const fn concept_demo() -> Self {
        Self {
            map_half_extent: FixedVec2::new(10 * UNITS_PER_METER, 6 * UNITS_PER_METER),
            character_half_extent: 400,
            movement_speed_per_second: 4 * UNITS_PER_METER,
            spawn: FixedVec2::new(0, 0),
        }
    }

    pub fn validate(self) -> Result<Self, WorldConfigError> {
        if self.map_half_extent.x <= self.character_half_extent
            || self.map_half_extent.y <= self.character_half_extent
        {
            return Err(WorldConfigError::CharacterDoesNotFit);
        }
        if self.character_half_extent <= 0 || self.movement_speed_per_second <= 0 {
            return Err(WorldConfigError::NonPositiveValue);
        }
        let limit = self.movement_limit();
        if self.spawn.x.abs() > limit.x || self.spawn.y.abs() > limit.y {
            return Err(WorldConfigError::SpawnOutsideMap);
        }
        Ok(self)
    }

    #[must_use]
    pub const fn movement_limit(self) -> FixedVec2 {
        FixedVec2::new(
            self.map_half_extent.x - self.character_half_extent,
            self.map_half_extent.y - self.character_half_extent,
        )
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum WorldConfigError {
    CharacterDoesNotFit,
    NonPositiveValue,
    SpawnOutsideMap,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct WorldSnapshot {
    pub tick: u64,
    pub character_position: FixedVec2,
    movement_remainder: FixedVec2,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct World {
    config: WorldConfig,
    state: WorldSnapshot,
}

impl World {
    pub fn new(config: WorldConfig) -> Result<Self, WorldConfigError> {
        let config = config.validate()?;
        Ok(Self {
            config,
            state: WorldSnapshot {
                tick: 0,
                character_position: config.spawn,
                movement_remainder: FixedVec2::default(),
            },
        })
    }

    #[must_use]
    pub const fn snapshot(&self) -> WorldSnapshot {
        self.state
    }

    #[must_use]
    pub const fn config(&self) -> WorldConfig {
        self.config
    }

    pub fn advance(&mut self, movement: MovementIntent) -> WorldSnapshot {
        let (delta_x, remainder_x) = movement_delta(
            self.config.movement_speed_per_second,
            movement.x(),
            self.state.movement_remainder.x,
        );
        let (delta_y, remainder_y) = movement_delta(
            self.config.movement_speed_per_second,
            movement.y(),
            self.state.movement_remainder.y,
        );
        self.state.movement_remainder = FixedVec2::new(remainder_x, remainder_y);
        self.apply_movement(FixedVec2::new(delta_x, delta_y));
        self.state.tick += 1;
        self.state
    }

    fn apply_movement(&mut self, delta: FixedVec2) {
        let limit = self.config.movement_limit();
        let desired = FixedVec2::new(
            self.state.character_position.x + delta.x,
            self.state.character_position.y + delta.y,
        );
        let clamped = FixedVec2::new(
            desired.x.clamp(-limit.x, limit.x),
            desired.y.clamp(-limit.y, limit.y),
        );
        if clamped.x != desired.x {
            self.state.movement_remainder.x = 0;
        }
        if clamped.y != desired.y {
            self.state.movement_remainder.y = 0;
        }
        self.state.character_position = clamped;
    }
}

fn movement_delta(speed: i64, input: i16, remainder: i64) -> (i64, i64) {
    let numerator = speed * i64::from(input) + remainder;
    (
        numerator / MOVEMENT_DENOMINATOR,
        numerator % MOVEMENT_DENOMINATOR,
    )
}

fn clamp_to_unit_circle(x: i64, y: i64) -> (i64, i64) {
    let length_squared = (x * x + y * y) as u64;
    let maximum_squared = (INPUT_MAX * INPUT_MAX) as u64;
    if length_squared <= maximum_squared {
        return (x, y);
    }
    let length = integer_sqrt_ceil(length_squared) as i64;
    (x * INPUT_MAX / length, y * INPUT_MAX / length)
}

fn integer_sqrt_ceil(value: u64) -> u64 {
    let floor = value.isqrt();
    if floor * floor == value {
        floor
    } else {
        floor + 1
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn moves_exactly_four_meters_in_one_second() {
        let mut world = World::new(WorldConfig::concept_demo()).expect("valid demo world");
        for _ in 0..TICKS_PER_SECOND {
            world.advance(MovementIntent::RIGHT);
        }
        assert_eq!(
            world.snapshot().character_position,
            FixedVec2::new(4_000, 0)
        );
    }

    #[test]
    fn character_cannot_leave_the_map() {
        let mut world = World::new(WorldConfig::concept_demo()).expect("valid demo world");
        for _ in 0..(TICKS_PER_SECOND * 10) {
            world.advance(MovementIntent::RIGHT);
        }
        assert_eq!(world.snapshot().character_position.x, 9_600);
    }

    #[test]
    fn diagonal_input_is_limited_to_unit_length() {
        let movement = MovementIntent::new(i16::MAX, i16::MAX);
        let length_squared = i64::from(movement.x()).pow(2) + i64::from(movement.y()).pow(2);
        assert!(length_squared <= INPUT_MAX.pow(2));
    }
}
