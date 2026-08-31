# Verify multiplayer on a test place, not in Studio

Studio's server-and-clients mode does not bind a movement controller, so simulated clients
cannot walk. Two sessions treated that as a blocking game bug and searched the codebase for
it; the same build published to a test place and joined from a real client works fine. The
standing rule "do not publish" had been read as "test only in Studio", which left every
multiplayer behaviour in the game unobservable.

We now publish to a separate place in the same universe and join it with real clients.
The live place remains off limits.

## Consequences

- Cart-to-Style transfer, placement isolation, voting, room reveals and ramming become
  testable for the first time. They were all marked UNVERIFIED because nobody could run them.
- Anything read out of a Studio playtest about the character rig is suspect. Studio reported
  a jointless character with 14 BallSocketConstraints, and reported it differently between
  solo and multiplayer runs. Rig facts must come from a real server.
- The test place shares the universe, so it shares live DataStores. Treat writes from it as
  writes to real player data.
