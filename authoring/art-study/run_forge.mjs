// Run the installed Prop Forge pipeline with Room Royale's own job storage.
process.env.FORGE_HOST = '127.0.0.1';
process.env.FORGE_PORT = '8766';
process.env.LOOKSHELF_BLENDER = 'D:/Blender/blender.exe';
const { default: config } = await import('file:///D:/code/lookshelf--forge/Tools/prop-forge/server/config.js');
config.paths.state = 'D:/code/RoomRoyale/build/art-study/forge-state';
config.paths.jobs = config.paths.state + '/jobs';
await import('file:///D:/code/lookshelf--forge/Tools/prop-forge/server/index.js');
