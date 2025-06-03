#include <app.inc> 
console(process_combined_stdout_stderr)
    main(args)
        use fpm_filesystem, only : join_path
        use fpm_package
        use utilities

        use, intrinsic :: iso_fortran_env, only: stdout => output_unit, &
                            stderr => error_unit
        

        integer :: i, nargs
        character(:), allocatable :: dir !< path to directory containing the fpm.toml file
        character(:), allocatable :: tomlfile
        type(package) :: p

        nargs = size(args)
        i = 1

        do while (i <= nargs)
            select case(args(i)%chars)
            case ('-d', '--dir')
                i = i + 1
                dir = args(i)
            case default
                if (i == 1) dir = args(i)
            end select
            i = i + 1
        end do

        call chdir(dir)

        tomlfile = join_path('', 'fpm.toml')
        call new(p, tomlfile)

        call p%export_to_forcegraph()

    endmain
end
