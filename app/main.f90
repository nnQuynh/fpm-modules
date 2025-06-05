#include <app.inc> 
console(process_combined_stdout_stderr)
    main(args)
        use fpm_filesystem, only : join_path
        use fpm_strings, only: string_t
        use fpm_package
        use utilities

        use, intrinsic :: iso_fortran_env, only: stdout => output_unit, &
                            stderr => error_unit
        

        integer :: i, j, k, l, nargs
        character(:), allocatable :: dir !< path to directory containing the fpm.toml file
        character(:), allocatable :: tomlfile
        character(:), allocatable :: chart
        type(string_t), allocatable :: exclude(:)
        type(package) :: p

        nargs = size(args)
        i = 1

        !default
        chart = 'mermaid'
        dir = './'
        allocate(exclude(0))

        do while (i <= nargs)
            select case(args(i)%chars)
            case ('-d', '--dir')
                i = i + 1
                if (i <= nargs) dir = args(i) 
            case ('-x','--exclude')
                i = i + 1
                if (i <= nargs) then
                    j = 0
                    k = 1
                    l = len(args(i)%chars)
                    do while (j < l)
                        j = j + 1
                        if (args(i)%chars(j:j) == '"') cycle
                        if (args(i)%chars(j:j) == ',') then
                            exclude = [exclude, string_t(trim(args(i)%chars(k:j-1)))]
                            k = j + 1
                        end if
                    end do
                    exclude = [exclude, string_t(trim(args(i)%chars(k:merge(l-1, l, args(i)%chars(l:l)=='"'))))]
                end if
            case ('-c','--chart')
                i = i + 1
                if (i <= nargs) chart = args(i)
            case default
                if (i == 1) dir = args(i)
            end select
            i = i + 1
        end do

        call chdir(dir)

        tomlfile = join_path('', 'fpm.toml')
        call new(p, tomlfile)

        select case(chart)
        case('mermaid')
            call p%export_to_mermaid(exclude=exclude)
        case('force')
            call p%export_to_forcegraph(exclude=exclude)
        case default
            print *, 'Unknown chart option. Supported values are "mermaid" and "force"'
        end select
    endmain
end
