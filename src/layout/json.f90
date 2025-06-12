module modules_layout_json
    use modules_layout, only: layout
    use modules_utilities, only: string_contains, handle_error
    use fpm_model, only: fpm_model_t
    use fpm_strings, only: string_t
    use fpm_error, only : error_t

    implicit none; private

    type, extends(layout), public :: json
    private
    contains
    private
    procedure, pass(this), public :: generate => generate_json
    end type

    contains

    subroutine generate_json(this, model, filepath, exclude)
        class(json), intent(in)                 :: this
        class(fpm_model_t), intent(inout)       :: model
        character(*), intent(in)                :: filepath
        type(string_t), optional, intent(in)    :: exclude(:)
        !private
        type(error_t), allocatable :: error
        integer :: n
        
        n = len(filepath)
        call model%dump(filepath(:n - len('.html'))//'.json', error, json=.true.)
        call handle_error(error)
    end subroutine
end module