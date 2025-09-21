# Smalruby Koshien Game Logic Implementation

## Overview

This document describes the complete game logic implementation for Smalruby Koshien competition system. The implementation provides a secure, scalable, and comprehensive game execution engine that supports AI battles with full event logging and state management.

## Architecture

### Core Components

1. **BattleJob** - Async job handler for game execution
2. **GameEngine** - Main game coordination and battle management
3. **AIEngine** - Secure Ruby code execution with sandboxing
4. **TurnProcessor** - Individual turn logic and game mechanics
5. **GameConstants** - Game configuration and constants

### Data Models

- **Game** - Main game entity with player AIs and status
- **GameRound** - Individual rounds (2 per game) with players and enemies
- **GameTurn** - Individual turns (max 50 per round) with events
- **Player** - Player state and position management
- **Enemy** - Enemy entities with AI behavior
- **GameEvent** - Comprehensive event logging system

## Game Flow

### 1. Game Initialization

When a game is started via the `startGame` GraphQL mutation:

```ruby
# StartGame mutation triggers BattleJob
BattleJob.perform_later(game.id)
```

### 2. Battle Execution

```ruby
game_engine = GameEngine.new(game)
result = game_engine.execute_battle
```

**Battle Flow:**
1. Execute 2 rounds sequentially
2. Each round: Initialize players, enemies, and items
3. Execute up to 50 turns per round
4. Determine round winners
5. Calculate overall winner based on round results

### 3. Round Initialization

For each round:
- Create GameRound record
- Initialize 2 players at start positions
- Initialize enemies based on map data
- Generate random item locations
- Set round status to `in_progress`

### 4. Turn Processing

Each turn:
1. Execute AI code for all active players
2. Process player actions (move, use items, wait)
3. Update enemy states and positions
4. Process collisions and interactions
5. Update scores and apply bonuses
6. Check win conditions
7. Log all events

## AI Execution Engine

### Security Features

The AIEngine provides secure Ruby code execution with multiple safety layers:

**Sandboxing:**
- Restricted binding with removed dangerous methods
- Timeout protection (10 seconds per turn)
- Exception handling and error isolation
- Memory and resource limits

**Allowed API Methods:**
- `move_up`, `move_down`, `move_left`, `move_right`
- `use_dynamite`, `use_bomb`
- `get_player_info`, `get_enemy_info`, `get_map_info`
- `get_item_info`, `get_turn_info`
- `wait`, `log`

**Example AI Code:**
```ruby
# Get current game state
player = get_player_info
enemies = get_enemy_info
map = get_map_info

# Simple AI logic
if player[:x] < 5
  move_right
elsif enemies.any? { |e| e[:x] == player[:x] && e[:y] == player[:y] }
  use_dynamite
else
  move_up
end
```

### Error Handling

- **AITimeoutError** - Code execution exceeds time limit
- **AISecurityError** - Security policy violation
- **AIExecutionError** - General execution failure

Players that encounter errors are marked as `timeout` and removed from active play.

## Game Mechanics

### Movement System

- **Valid Movements**: Up, Down, Left, Right
- **Collision Detection**: Walls, water, boundaries
- **Position Tracking**: Current and previous positions stored

### Item System

**Items Available:**
- Items 1-5: Positive score bonuses (10, 20, 30, 40, 60 points)
- Items 6-9: Negative score penalties (-10, -20, -30, -40 points)
- Dynamite: Explosive item for destroying walls/enemies
- Bomb: More powerful explosive item

**Item Collection:**
- Automatic when player moves to item location
- Item removed from map after collection
- Score immediately updated

### Combat System

**Enemy Interaction:**
- Enemies can attack adjacent players
- Attack power configurable per enemy
- Players lose points when attacked (-10 default)
- Enemies can be destroyed with explosives

**Explosion Mechanics:**
- Dynamite and bomb create explosion effects
- Destroy breakable walls in range
- Damage enemies in blast radius
- Can affect multiple players

### Scoring System

**Score Sources:**
- Item collection: +10 to +60 points (positive items)
- Item penalties: -10 to -40 points (negative items)
- Walk bonus: +3 points every 5 moves
- Goal bonus: +100 points for reaching goal
- Enemy damage: -10 points when attacked

**Character Leveling:**
- Level calculated from total score: `(score - 1) / 20`
- Level affects player capabilities and appearance
- Maximum level: 8

### Win Conditions

**Round End Conditions:**
1. Player reaches goal position
2. All players finished/timeout
3. Maximum turns reached (50)

**Overall Winner:**
1. Player with most round wins
2. If tied, player with highest total score across rounds
3. If still tied, result is draw

## Event Logging System

All game actions are logged as GameEvent records:

**Event Types:**
- `MOVE` - Player movement
- `MOVE_BLOCKED` - Invalid movement attempt
- `USE_DYNAMITE` / `USE_BOMB` - Item usage
- `COLLECT_ITEM` - Item collection
- `ENEMY_ATTACK` - Enemy attacks player
- `PLAYER_COLLISION` - Player collision
- `WALK_BONUS` - Walk bonus applied
- `AI_TIMEOUT` - AI execution failure

**Event Data Structure:**
```ruby
{
  player: player_reference,
  event_type: "MOVE",
  event_data: {
    from: { x: 1, y: 1 },
    to: { x: 2, y: 1 },
    direction: "right"
  },
  occurred_at: timestamp
}
```

## Configuration

### Game Constants

```ruby
# Game Settings
N_PLAYERS = 2
N_ROUNDS = 2
MAX_TURN = 50
TURN_DURATION = 10  # seconds

# Items
N_DYNAMITE = 2
N_BOMB = 2
WALK_BONUS = 3
WALK_BONUS_BOUNDARY = 5

# Map Elements
MAP_BLANK = 0
MAP_WALL1 = 1
MAP_WALL2 = 2
MAP_GOAL = 3
MAP_WATER = 4
MAP_BREAKABLE_WALL = 5
```

## API Integration

### GraphQL Mutations

**Start Game:**
```graphql
mutation($gameId: ID!) {
  startGame(gameId: $gameId) {
    game {
      id
      status
      winner
    }
    errors
  }
}
```

### Job Processing

Games are processed asynchronously using ActiveJob:

```ruby
# Queue a battle
BattleJob.perform_later(game_id)

# Process immediately (for testing)
BattleJob.perform_now(game_id)
```

## Testing

### Test Coverage

Comprehensive test suite covering:

1. **GameEngine Tests** - Battle execution, round management, winner determination
2. **AIEngine Tests** - Code execution, security, API methods
3. **TurnProcessor Tests** - Movement, items, collisions, scoring
4. **BattleJob Tests** - Async execution, error handling

### Example Test

```ruby
RSpec.describe GameEngine do
  it "executes a complete battle" do
    result = game_engine.execute_battle

    expect(result[:success]).to be true
    expect(result[:winner]).to be_in([:first, :second, nil])
    expect(game.game_rounds.count).to eq(2)
  end
end
```

## Performance Considerations

### Optimization Features

1. **Async Processing** - Games don't block web requests
2. **Timeout Protection** - Prevents runaway AI code
3. **Memory Management** - Sandboxed execution contexts
4. **Database Optimization** - Efficient queries with includes
5. **Event Batching** - Efficient event logging

### Monitoring

- Comprehensive Rails logging
- Error tracking and reporting
- Game execution metrics
- AI performance monitoring

## Security

### AI Code Security

1. **Sandboxed Execution** - Restricted binding environment
2. **Method Filtering** - Dangerous methods removed
3. **Timeout Protection** - Execution time limits
4. **Resource Limits** - Memory and CPU constraints
5. **Input Validation** - AI action validation

### Data Security

1. **Input Sanitization** - All user inputs validated
2. **SQL Injection Prevention** - ActiveRecord protections
3. **Access Control** - Proper authentication/authorization
4. **Audit Logging** - Complete event trail

## Deployment

### Requirements

- Ruby 3.3+
- Rails 8.0+
- PostgreSQL (for JSON support)
- Redis (for job processing)

### Configuration

```ruby
# config/application.rb
config.autoload_paths << Rails.root.join("app", "services")

# Job queue configuration
config.active_job.queue_adapter = :sidekiq  # or :resque
```

## Future Enhancements

### Planned Features

1. **Advanced AI APIs** - More game state information
2. **Team Battles** - Multi-player team support
3. **Tournament System** - Bracket-style competitions
4. **Replay System** - Game replay functionality
5. **Performance Analytics** - AI performance metrics
6. **Map Editor** - Visual map creation tools

### Extensibility

The system is designed for easy extension:

- New AI API methods can be added to AIExecutionContext
- Additional game mechanics via TurnProcessor
- Custom event types for new features
- Pluggable scoring systems
- Configurable game rules

## Troubleshooting

### Common Issues

1. **AI Timeout** - Check code complexity and loops
2. **Invalid Movement** - Verify map boundaries and obstacles
3. **Missing Events** - Check event logging in TurnProcessor
4. **Job Failures** - Monitor job queue and error logs

### Debug Tools

```ruby
# Enable debug logging
Rails.logger.level = Logger::DEBUG

# Manual game execution
game_engine = GameEngine.new(game)
game_engine.execute_battle

# Check game state
game.game_rounds.includes(:players, :enemies, game_turns: :game_events)
```

## Conclusion

The Smalruby Koshien game logic implementation provides a robust, secure, and scalable foundation for AI programming competitions. The architecture supports complex game mechanics while maintaining security and performance, making it suitable for educational environments and competitive programming contests.