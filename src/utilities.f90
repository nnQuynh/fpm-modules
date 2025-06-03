module utilities
    use, intrinsic :: iso_c_binding

    implicit none; private

    public :: chdir

    interface
        integer function chdir_c(path) bind(c, name="chdir")
        import c_char
            character(kind=c_char) :: path(*)
        end function
  end interface

    contains

    subroutine chdir(path, ierr)
        character(*), intent(in)        :: path
        integer, optional, intent(out)  :: ierr
        integer :: loc_err

        loc_err =  chdir_c(path//c_null_char)

        if (present(ierr)) ierr = loc_err
    end subroutine
end module