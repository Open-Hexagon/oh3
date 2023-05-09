local test_module = arg[2]
if test_module == nil then
    error("You need to specify a module for testing!")
end

-- workaround for running busted with love
table.remove(arg, 1)
table.remove(arg, 1)

require(test_module)
