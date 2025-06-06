module fpm_package
    use fpm_strings, only: string_t
    use fpm_command_line, only : fpm_build_settings, get_command_line_settings, get_fpm_env
    use fpm_dependency, only : dependency_tree_t, new_dependency_tree
    use fpm_error, only : error_t, fpm_stop
    use fpm_filesystem, only : join_path
    use fpm_manifest, only : package_config_t, get_package_data
    use fpm_model, only: fpm_model_t
    use fpm, only: build_model

    implicit none; private

    public :: new

    type, extends(package_config_t), public :: package
        private
        type(fpm_model_t), public :: model
    contains
        procedure, pass(this), public :: create => package_create
        procedure, pass(this), public :: export_to_mermaid => package_export_to_mermaid
        procedure, pass(this), public :: export_to_forcegraph => package_export_to_forcegraph
    end type

    interface new
        module procedure :: package_new_from_file
    end interface

    interface string_contains
        module procedure :: string_contains_string,     &
                            string_contains_character
    end interface

    contains

    subroutine package_new_from_file(pack, file)
        class(package), intent(out)         :: pack
        character(*), intent(in), optional  :: file
        !private
        type(error_t), allocatable :: error
        character(:), allocatable :: filepath
        

        if (present(file)) then
            filepath = file
        else
            filepath = 'fpm.toml'
        end if
        print*, filepath
        call get_package_data(pack%package_config_t, filepath, error, apply_defaults=.true.)
        call handle_error(error)

        call pack%create()
    end subroutine

    subroutine package_create(this)
        class(package), intent(inout)   :: this
        !private
        type(fpm_build_settings) :: settings
        type(error_t), allocatable :: error

        settings = fpm_build_settings(  &
        & profile=" ",&
        & dump='fpm_model.toml',&
        & prune= .false., &
        & compiler=get_fpm_env("FC", "gfortran"), &
        & c_compiler=get_fpm_env("CC", " "), &
        & cxx_compiler= get_fpm_env("CXX", " "), &
        & archiver= get_fpm_env("AR", " "), &
        & path_to_config= " ", &
        & flag=" ", &
        & cflag=" ", &
        & cxxflag=" ", &
        & ldflag=" ", &
        & list=.false.,&
        & show_model=.false.,&
        & build_tests=.false.,&
        & verbose=.false.)

        call build_model(this%model, settings, this%package_config_t, error)
        if (allocated(error)) then
            call fpm_stop(1,'*package_build* Model error: '//error%message)
        end if
    end subroutine

    subroutine package_export_to_mermaid(this, file, exclude)
        class(package), intent(inout)       :: this
        character(*), optional, intent(in)  :: file
        type(string_t), optional, intent(in):: exclude(:)
        !private
        type(string_t), allocatable :: excludes_mods(:)
        type(error_t), allocatable :: error
        character(:), allocatable :: filepath
        integer :: i, j, k, l, unit

        if (present(file)) then
            filepath = file
        else
            filepath = this%name//'.html'
        end if

        allocate(excludes_mods(0))

        !call this%model%dump(filepath, error, json=.true.)
        !call handle_error(error)

        open(newunit=unit, file=filepath, action='write', status='replace')
        write(unit,'(*(A,/))')              &
        '<!DOCTYPE html>'               ,   &
        '<html lang="en">'              ,   &
        '<head>'                        ,   &
        '   <meta charset="utf-8">'     ,   &
        '</head>'                       ,   &
        '<body>'                        ,   &
        '   <div class="diagram-container" id="diagram-container">'      ,   &
        '       <pre class="mermaid">', &
        '       flowchart LR'
        do i = 1, size(this%model%packages)
            if (present(exclude)) then
                if (string_contains(exclude, this%model%packages(i)%name)) then
                    do j = 1, size(this%model%packages(i)%sources)
                        do k = 1, size(this%model%packages(i)%sources(j)%modules_provided)
                            excludes_mods = [excludes_mods, this%model%packages(i)%sources(j)%modules_provided(k)]
                        end do
                    end do
                    cycle
                end if
            end if
            write(unit,'("      subgraph package_", A)') this%model%packages(i)%name
            do j = 1, size(this%model%packages(i)%sources)
                do k = 1, size(this%model%packages(i)%sources(j)%modules_provided)
                    write(unit,'("      ", A)') this%model%packages(i)%sources(j)%modules_provided(k)%s
                end do
            end do
            write(unit,'(A)') '     end'
        end do
        write(unit,'("      subgraph external_module")')
        do j = 1, size(this%model%external_modules)
            write(unit,'("      ", A)') this%model%external_modules(j)%s
        end do
        write(unit,'(A)') '     end'
        do i = 1, size(this%model%packages)
            if (present(exclude)) then; if (string_contains(exclude, this%model%packages(i)%name)) cycle; end if
            do j = 1, size(this%model%packages(i)%sources)
                do k = 1, size(this%model%packages(i)%sources(j)%modules_provided)
                    do l = 1, size(this%model%packages(i)%sources(j)%modules_used)
                        if (.not. string_contains(excludes_mods, this%model%packages(i)%sources(j)%modules_used(l))) then
                            write(unit,'("      ", A, "-->", A)') this%model%packages(i)%sources(j)%modules_provided(k)%s, this%model%packages(i)%sources(j)%modules_used(l)%s
                        end if
                    end do
                    exit !set all the use to belong to the first module in the file
                end do
            end do
        end do
        write(unit,'(*(A,/))')              &
        '       </pre>'                 ,   &
        '   </div>'                     ,   &
        '<script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>',   &
        '<script src="https://unpkg.com/@panzoom/panzoom@4.6.0/dist/panzoom.min.js"></script>', &
        '<script>mermaid.initialize({startOnLoad:false, maxEdges: 4000});', &
        '    mermaid.run({', &
        '    querySelector: ".mermaid",', &
        '    postRenderCallback: (id) => {', &
        '        const container = document.getElementById("diagram-container");', &
        '        const svgElement = container.querySelector("svg");', &
        '        // Initialize Panzoom', &
        '        const panzoomInstance = Panzoom(svgElement, {', &
        '            maxScale: 5,', &
        '            minScale: 0.5,', &
        '            step: 0.1,', &
        '        });', &
        '        // Add mouse wheel zoom', &
        '        container.addEventListener("wheel", (event) => {', &
        '            panzoomInstance.zoomWithWheel(event);', &
        '        });', &
        '    }', &
        '});', &
        '</script>'                        ,   &
        '</body>'                       ,   &
        '</html>'

        close(unit)
    end subroutine

    subroutine package_export_to_forcegraph(this, file, exclude)
        class(package), intent(inout)       :: this
        character(*), optional, intent(in)  :: file
        type(string_t), optional, intent(in):: exclude(:)
        !private
        type(error_t), allocatable :: error
        character(:), allocatable :: filepath
        type(string_t), allocatable :: excludes_mods(:)
        type(string_t), allocatable :: modules(:)
        integer :: i, j, k, l, unit, s

        allocate(modules(0), excludes_mods(0))
        if (present(file)) then
            filepath = file
        else
            filepath = this%name//'.html'
        end if

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
        do i = 1, size(this%model%packages)
            if (present(exclude)) then
                if (string_contains(exclude, this%model%packages(i)%name)) then
                    do j = 1, size(this%model%packages(i)%sources)
                        do k = 1, size(this%model%packages(i)%sources(j)%modules_provided)
                            excludes_mods = [excludes_mods, this%model%packages(i)%sources(j)%modules_provided(k)]
                        end do
                    end do
                    cycle
                end if
            end if
            do j = 1, size(this%model%packages(i)%sources)
                do k = 1, size(this%model%packages(i)%sources(j)%modules_provided)
                    write(unit,'("{""id"": """, A ,""", ""group"": """, i0 ,"""},")', advance='no') &
                        this%model%packages(i)%sources(j)%modules_provided(k)%s, i
                        modules = [modules, this%model%packages(i)%sources(j)%modules_provided(k)]
                end do
            end do
        end do
        do j = 1, size(this%model%external_modules)
            write(unit,'("{""id"": """, A ,""", ""group"": """, i0 ,"""},")', advance='no') &
                        this%model%external_modules(j)%s, 0
            modules = [modules, this%model%external_modules(j)]
        end do
        inquire(unit=unit, pos=s); read(unit,'(A)', advance='no', pos=s-1)
        write(unit,'(A)', advance='no') '],'
        write(unit,'(A)', advance='no') '"links": ['
        do i = 1, size(this%model%packages)
            if (present(exclude)) then; if (string_contains(exclude, this%model%packages(i)%name)) cycle; end if
            do j = 1, size(this%model%packages(i)%sources)
                do k = 1, size(this%model%packages(i)%sources(j)%modules_provided)
                    do l = 1, size(this%model%packages(i)%sources(j)%modules_used)
                        if (string_contains(modules, this%model%packages(i)%sources(j)%modules_used(l)) .and. &
                            .not. string_contains(excludes_mods, this%model%packages(i)%sources(j)%modules_used(l))) then
                            write(unit,'("{""source"": """, A ,""", ""target"": """, A ,""", ""value"":", i0,"},")', advance='no') &
                                this%model%packages(i)%sources(j)%modules_provided(k)%s, this%model%packages(i)%sources(j)%modules_used(l)%s, merge(5, 1, i == 1)
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

    subroutine handle_error(error_)
        type(error_t), optional, intent(in) :: error_
        if (present(error_)) then
            write (*, '("[Error]", 1x, a)') error_%message
            stop 1
        end if
    end subroutine

    logical function string_contains_string(lhs, rhs) result(res)
        type(string_t), intent(in) :: lhs(:)
        type(string_t), intent(in) :: rhs
        !private
        integer :: i

        res = .false.
        do i = 1, size(lhs)
            if (lhs(i)%s == rhs%s) then
                res = .true.
                exit
            end if
        end do
    end function

    logical function string_contains_character(lhs, rhs) result(res)
        type(string_t), intent(in)  :: lhs(:)
        character(*), intent(in)    :: rhs
        !private
        integer :: i

        res = .false.
        do i = 1, size(lhs)
            if (lhs(i)%s == rhs) then
                res = .true.
                exit
            end if
        end do
    end function
end module
