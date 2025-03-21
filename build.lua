config = {
	buildMode = arg[1] or 'debug',
	targetSystem = arg[2],
	compiler = 'clang',
}

---| Utility |---
function Exec(arglist)
	local cmd = table.concat(arglist, ' ')
	print('-> ' .. cmd)
	local ok = os.execute(cmd)
	return ok
end

function DetectSystem()
	local c = package.config:sub(1,1)
	if c == '\\' then
		return 'windows'
	end

	-- Unix like
	local handle = io.popen('uname -s')
	local kernel = handle:read('*a')
	handle:close()

	kernel = kernel:lower()
	if kernel:find('linux') then
		return 'linux'
	end

	error('Could not detect target system, please provide it explicitly', 2)
end

function FileExists(path)
   local f = io.open(path, "r")
   if f then
	   f:close()
	   return true
	else
		return false
	end
end

function Append(tbl, ...)
	assert(type(tbl) == 'table', 'Expected table got:'.. type(tbl))
	local items = {...}
	for _, v in ipairs(items) do
		tbl[#tbl+1] = v
	end
end

Unpack = table.unpack

---| Build targets |---
function BuildMimalloc()
	local cflags = {'-O3', '-std=c17', '-fno-strict-aliasing'}
	local iflags = {'-Ideps/mimalloc/include'}
	local wflags = {'-Wall', '-Wextra', '-Wno-pointer-sign'}

	if config.targetSystem == 'linux' then
		Append(cflags, '-fPIC')
	end

	local cmd = {config.compiler, '-c', 'deps/mimalloc/src/static.c', '-o', 'deps/mimalloc/mimalloc.o'}
	Append(cmd, Unpack(cflags))
	Append(cmd, Unpack(iflags))
	Append(cmd, Unpack(wflags))

	assert(Exec(cmd), 'Failed to compile mimalloc')
end

function BuildKibi()
	local cflags = {'-std=c17', '-fno-strict-aliasing'}
	local iflags = {'-Ideps/include', '-Isrc'}
	local wflags = {'-Wall', '-Wextra', '-Wno-pointer-sign'}
	local lflags = {}

	if config.buildMode == 'debug' then
		Append(cflags, '-O0', '-g', '-pipe')
	elseif config.buildMode == 'release' then
		Append(cflags, '-O3', '-s')
	end

	if config.targetSystem == 'windows' then
		Append(lflags, '-ladvapi32')
		Append(wflags, '-Wno-unused-command-line-argument')
	end

	if config.targetSystem == 'linux' then
		Append(lflags, '-static-libgcc')
		Append(cflags, '-fPIC')
	end

	local cmd = {config.compiler, '-o', 'kibi.exe', 'src/main.c', 'src/base/base.c'} -- , 'deps/mimalloc/mimalloc.o'}
	Append(cmd, Unpack(cflags))
	Append(cmd, Unpack(iflags))
	Append(cmd, Unpack(wflags))
	Append(cmd, Unpack(lflags))

	assert(Exec(cmd), 'Failed to compile kibi.exe')
end

---| Main |---
do
	--- Attempt to detect the target system
	if not config.targetSystem  then
		config.targetSystem = DetectSystem()
	end

	print('System: '.. config.targetSystem)
	print('Compiler: '.. config.compiler)
	print('Build Mode: '.. config.buildMode)

	if not FileExists('deps/mimalloc/mimalloc.o') then
		BuildMimalloc()
	end
	BuildKibi()
end

