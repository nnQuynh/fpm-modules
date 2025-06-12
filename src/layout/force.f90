module modules_layout_force
    use modules_layout, only: layout
    use fpm_model, only: fpm_model_t
    use modules_utilities, only: string_contains
    use fpm_strings, only: string_t
    use fpm_error, only : error_t

    implicit none; private

    type, extends(layout), public :: force
    private
    contains
    private
    procedure, pass(this), public :: generate => generate_force
    end type

    contains

    subroutine generate_force(this, model, filepath, exclude)
        class(force), intent(in)                :: this
        class(fpm_model_t), intent(inout)       :: model
        character(*), intent(in)                :: filepath
        type(string_t), optional, intent(in)    :: exclude(:)
        !private
        type(error_t), allocatable :: error
        type(string_t), allocatable :: excludes_mods(:)
        type(string_t), allocatable :: modules(:)
        integer :: i, j, k, l, s, unit

        allocate(modules(0))

        open(newunit=unit, file=filepath, action='readwrite', status='replace', access='stream', form='formatted')
        write(unit,'(*(A,/))')              &
        '<!DOCTYPE html>'               ,   &
        '<html lang="en">'              ,   &
        '<head>'                        ,   &
        '   <style> body { margin: 0; } </style>'     ,   &
        '   <script src="https://cdn.jsdelivr.net/npm/force-graph@1.49.6/dist/force-graph.min.js"></script>'     ,   &
        '   <link href="https://cdn.jsdelivr.net/npm/force-graph@1.49.6/src/force-graph.min.css" rel="stylesheet">'     ,   &
        '</head>'                       ,   &
        '<body>'                        ,   &
        '   <div id="graph"></div>'      ,   &
        '       <script>'
        write(unit,'(A)', advance='no') "       var datastr = '{"
        write(unit,'(A)', advance='no') '"nodes": ['
        do i = 1, size(model%packages)
            if (present(exclude)) then
                if (string_contains(exclude, model%packages(i)%name)) then
                    do j = 1, size(model%packages(i)%sources)
                        do k = 1, size(model%packages(i)%sources(j)%modules_provided)
                            excludes_mods = [excludes_mods, model%packages(i)%sources(j)%modules_provided(k)]
                        end do
                    end do
                    cycle
                end if
            end if
            do j = 1, size(model%packages(i)%sources)
                do k = 1, size(model%packages(i)%sources(j)%modules_provided)
                    write(unit,'("{""id"": """, A ,""", ""group"": """, i0 ,"""},")', advance='no') &
                        model%packages(i)%sources(j)%modules_provided(k)%s, i
                        modules = [modules, model%packages(i)%sources(j)%modules_provided(k)]
                end do
            end do
        end do
        do j = 1, size(model%external_modules)
            write(unit,'("{""id"": """, A ,""", ""group"": """, i0 ,"""},")', advance='no') &
                        model%external_modules(j)%s, 0
            modules = [modules, model%external_modules(j)]
        end do
        inquire(unit=unit, pos=s); read(unit,'(A)', advance='no', pos=s-1)
        write(unit,'(A)', advance='no') '],'
        write(unit,'(A)', advance='no') '"links": ['
        do i = 1, size(model%packages)
            if (present(exclude)) then; if (string_contains(exclude, model%packages(i)%name)) cycle; end if
            do j = 1, size(model%packages(i)%sources)
                do k = 1, size(model%packages(i)%sources(j)%modules_provided)
                    do l = 1, size(model%packages(i)%sources(j)%modules_used)
                        if (string_contains(modules, model%packages(i)%sources(j)%modules_used(l)) .and. &
                            .not. string_contains(excludes_mods, model%packages(i)%sources(j)%modules_used(l))) then
                            write(unit,'("{""source"": """, A ,""", ""target"": """, A ,""", ""value"":", i0,"},")', advance='no') &
                                model%packages(i)%sources(j)%modules_provided(k)%s, model%packages(i)%sources(j)%modules_used(l)%s, merge(5, 1, i == 1)
                        end if
                    end do
                    exit !set all the use to belong to the first module in the file
                end do
            end do
        end do
        inquire(unit=unit, pos=s); read(unit,'(A)', advance='no', pos=s-1)
        write(unit,'(A)', advance='no') ']'
        write(unit,'(A)') "}';"
        write(unit,'(*(A,/))')              &
        '       data = JSON.parse(datastr);'                 ,   &
        '       const Graph = new ForceGraph(document.getElementById("graph"))'                     ,   &
        '       .graphData(data)',   &
        '       .nodeId("id")', &
        '       .nodeVal("val")', &
        '       .nodeLabel("id")', &
        '       .nodeAutoColorBy("group")', &
        '       .linkSource("source")', &
        '       .linkTarget("target")', &
        '       </script>'                        ,   &
        '   </body>'                       ,   &
        '</html>'
        close(unit)
    end subroutine
end module