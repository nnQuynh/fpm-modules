module modules_layout_mermaid
    use modules_layout, only: layout
    use modules_utilities, only: string_contains
    use fpm_model, only: fpm_model_t
    use fpm_strings, only: string_t
    use fpm_error, only : error_t

    implicit none; private

    type, extends(layout), public :: mermaid
    private
    contains
    private
    procedure, pass(this), public :: generate => generate_mermaid
    end type

    contains

    subroutine generate_mermaid(this, model, filepath, exclude)
        class(mermaid), intent(in)              :: this
        class(fpm_model_t), intent(inout)       :: model
        character(*), intent(in)                :: filepath
        type(string_t), optional, intent(in)    :: exclude(:)
        !private
        type(string_t), allocatable :: excludes_mods(:)
        type(error_t), allocatable :: error
        integer :: i, j, k, l, unit

        allocate(excludes_mods(0))

        open(newunit=unit, file=filepath, action='write', status='replace')
        write(unit,'(*(A,/))')              &
        '<!DOCTYPE html>'               ,   &
        '<html lang="en">'              ,   &
        '<head>'                        ,   &
        '   <meta charset="utf-8">'     ,   &
        '</head>'                       ,   &
        '<body>'                        ,   &
        '    <div class="diagram-container" id="diagram-container">'      ,   &
        '        <pre class="mermaid">', &
        'flowchart LR'
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
            write(unit,'("    subgraph package_", A)') model%packages(i)%name
            do j = 1, size(model%packages(i)%sources)
                do k = 1, size(model%packages(i)%sources(j)%modules_provided)
                    write(unit,'("        ", A)') model%packages(i)%sources(j)%modules_provided(k)%s
                end do
            end do
            write(unit,'(A)') '    end'
        end do
        write(unit,'("    subgraph external_module")')
        do j = 1, size(model%external_modules)
            if (len_trim(model%external_modules(j)%s) > 0) write(unit,'("        ", A)') model%external_modules(j)%s
        end do
        write(unit,'(A)') '    end'
        do i = 1, size(model%packages)
            if (present(exclude)) then; if (string_contains(exclude, model%packages(i)%name)) cycle; end if
            do j = 1, size(model%packages(i)%sources)
                do k = 1, size(model%packages(i)%sources(j)%modules_provided)
                    do l = 1, size(model%packages(i)%sources(j)%modules_used)
                        if (.not. string_contains(excludes_mods, model%packages(i)%sources(j)%modules_used(l))) then
                            write(unit,'("    ", A, "-->", A)') model%packages(i)%sources(j)%modules_used(l)%s, model%packages(i)%sources(j)%modules_provided(k)%s
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
end module