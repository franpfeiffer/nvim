return {
    {
        'franpfeiffer/term2.nvim',
        config = function()
            require('term2').setup({
                height = 12,
                keymap = '<leader>tt'
            })
        end
    }
}
