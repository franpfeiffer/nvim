return {
    {
        'franpfeiffer/term2.nvim',
        config = function()
            require('term2').setup({
                keymap = '<leader>t2'
            })
        end
    }
}
