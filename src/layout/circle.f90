module modules_layout_circle
    use modules_layout, only: layout
    use modules_utilities, only: string_contains, handle_error
    use fpm_model, only: fpm_model_t
    use fpm_strings, only: string_t
    use fpm_error, only : error_t
    use fpm_filesystem, only: basename

    implicit none; private

    type, extends(layout), public :: circle
    private
    contains
    private
    procedure, pass(this), public :: generate => generate_circle
    end type

    contains

    subroutine generate_circle(this, model, filepath, exclude)
        class(circle), intent(in)               :: this
        class(fpm_model_t), intent(inout)       :: model
        character(*), intent(in)                :: filepath
        type(string_t), optional, intent(in)    :: exclude(:)
        !private
        integer :: i, j, k, s, unit

        open(newunit=unit, file=filepath, action='readwrite', status='replace', access='stream', form='formatted')
        write(unit,'(*(A,/))')              &
        '<!DOCTYPE html>'               ,   &
        '<html lang="en">'              ,   &
        '<head>'                        ,   &
        '   <style> body { margin: 0; } </style>'     ,   &
        '   <script src="https://cdn.jsdelivr.net/npm/circlepack-chart"></script>'     ,   &
        '</head>'                       ,   &
        '<body>'                        ,   &
        '   <div id="graph"></div>'      ,   &
        '       <script type="module">', &
        '       import { scaleOrdinal } from "https://esm.sh/d3-scale";', &
        '       import { schemePaired } from "https://esm.sh/d3-scale-chromatic";'
        write(unit,'(A)', advance='no') "       var datastr = '{"
        write(unit,'("""name"": """, A, """,")', advance='no') basename(filepath)
        write(unit,'(A)', advance='no') '"children": ['
        do i = 1, size(model%packages)
            if (present(exclude)) then
                if (.not. string_contains(exclude, model%packages(i)%name)) then
                    write(unit,'("{""name"": """, A ,""", ""children"": [")', advance='no') model%packages(i)%name
                    do j = 1, size(model%packages(i)%sources)
                        inquire(file=model%packages(i)%sources(j)%file_name, size=s)
                        do k = 1, size(model%packages(i)%sources(j)%modules_provided)
                            write(unit,'("{""name"": """, A ,""", ""value"": """, i0 ,"""},")', advance='no') &
                                model%packages(i)%sources(j)%modules_provided(k)%s, s
                        end do
                    end do
                    inquire(unit=unit, pos=s); read(unit,'(A)', advance='no', pos=s-1)
                    write(unit,'(A)', advance='no') ']},'
                end if
            end if
            
        end do
        inquire(unit=unit, pos=s); read(unit,'(A)', advance='no', pos=s-1)
        write(unit,'(A)', advance='no') ']'
        write(unit,'(A)') "}';"
        write(unit,'(*(A,/))') &
        '       var data = JSON.parse(datastr);', &
        '       const color = scaleOrdinal(schemePaired);', &
        '       const Graph = new CirclePack(document.getElementById("graph"))', &
        '       .data(data)', &
        '       .color(d => color(d.name))', &
        '       .minCircleRadius(8);', &
        '       </script>', &
        '   </body>', &
        '</html>'
        close(unit)
    end subroutine
end module