! Copyright (C) 2014 Santiago Badia, Alberto F. Martín and Javier Principe
!
! This file is part of FEMPAR (Finite Element Multiphysics PARallel library)
!
! FEMPAR is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! FEMPAR is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with FEMPAR. If not, see <http://www.gnu.org/licenses/>.
!
! Additional permission under GNU GPL version 3 section 7
!
! If you modify this Program, or any covered work, by linking or combining it 
! with the Intel Math Kernel Library and/or the Watson Sparse Matrix Package 
! and/or the HSL Mathematical Software Library (or a modified version of them), 
! containing parts covered by the terms of their respective licenses, the
! licensors of this Program grant you additional permission to convey the 
! resulting work. 
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

module output_handler_base_names

USE types_names
USE fe_space_names,              only: serial_fe_space_t, fe_iterator_t, fe_accessor_t
USE fe_function_names,           only: fe_function_t
USE output_handler_fe_field_names
USE output_handler_patch_names
USE output_handler_cell_fe_function_names

implicit none
#include "debug.i90"
private

    integer(ip), parameter :: fe_functions_initial_size = 10

    type, abstract :: output_handler_base_t
    private
        class(serial_fe_space_t),     pointer     :: fe_space => NULL()
        type(output_handler_fe_field_t),    allocatable :: fe_fields(:)
        integer(ip)                               :: number_fields = 0
    contains
        procedure, public :: free                          => output_handler_base_free
        procedure, public :: attach_fe_space               => output_handler_base_attach_fe_space
        procedure         :: resize_fe_functions_if_needed => output_handler_base_resize_fe_functions_if_needed
        procedure, public :: add_fe_function               => output_handler_base_add_fe_function
        procedure, public :: fill_data                     => output_handler_base_fill_data
        procedure(output_handler_base_write),       public, deferred :: write
        procedure(output_handler_base_append_cell), public, deferred :: append_cell
    end type

    abstract interface
        subroutine output_handler_base_write(this)
            import output_handler_base_t
            class(output_handler_base_t), intent(in) :: this
        end subroutine

        subroutine output_handler_base_append_cell(this)
            import output_handler_base_t
            class(output_handler_base_t), intent(in) :: this
        end subroutine
    end interface

public :: output_handler_base_t

contains

!---------------------------------------------------------------------
!< output_handler_BASE_T PROCEDURES
!---------------------------------------------------------------------

    subroutine output_handler_base_free(this)
    !-----------------------------------------------------------------
    !< Free output_handler_base_t derived type
    !-----------------------------------------------------------------
        class(output_handler_base_t), intent(inout) :: this
        integer(ip)                                 :: i
    !-----------------------------------------------------------------
        if(allocated(this%fe_fields)) then
            do i=1, size(this%fe_fields)
                call this%fe_fields(i)%free()
            enddo
            deallocate(this%fe_fields)
        endif
        this%number_fields = 0
        nullify(this%fe_space)
    end subroutine output_handler_base_free


    subroutine output_handler_base_attach_fe_space(this, fe_space)
    !-----------------------------------------------------------------
    !< Attach a fe_space to the output_handler_base_t derived type
    !-----------------------------------------------------------------
        class(output_handler_base_t),          intent(inout) :: this
        class(serial_fe_space_t), target,      intent(in)    :: fe_space
    !-----------------------------------------------------------------
        this%fe_space => fe_space
    end subroutine output_handler_base_attach_fe_space


    subroutine output_handler_base_resize_fe_functions_if_needed(this, number_fields)
    !-----------------------------------------------------------------
    !< Attach a fe_space to the output_handler_base_t derived type
    !-----------------------------------------------------------------
        class(output_handler_base_t),       intent(inout) :: this
        integer(ip),                        intent(in)    :: number_fields
        integer(ip)                                       :: current_size
        type(output_handler_fe_field_t), allocatable      :: temp_fe_functions(:)
    !-----------------------------------------------------------------
        if(.not. allocated(this%fe_fields)) then
            allocate(this%fe_fields(fe_functions_initial_size))
        elseif(number_fields > size(this%fe_fields)) then
            current_size = size(this%fe_fields)
            allocate(temp_fe_functions(current_size))
            temp_fe_functions(1:current_size) = this%fe_fields(1:current_size)
            deallocate(this%fe_fields)
            allocate(temp_fe_functions(int(1.5*current_size)))
            this%fe_fields(1:current_size) = temp_fe_functions(1:current_size)
            deallocate(temp_fe_functions)
        endif
    end subroutine output_handler_base_resize_fe_functions_if_needed


    subroutine output_handler_base_add_fe_function(this, fe_function, field_id, name)
    !-----------------------------------------------------------------
    !< Attach a fe_space to the output_handler_base_t derived type
    !-----------------------------------------------------------------
        class(output_handler_base_t),       intent(inout) :: this
        type(fe_function_t),                intent(in)    :: fe_function
        integer(ip),                        intent(in)    :: field_id
        character(len=*),                   intent(in)    :: name
    !-----------------------------------------------------------------
        call this%resize_fe_functions_if_needed(this%number_fields+1)
        this%number_fields = this%number_fields + 1
        call this%fe_fields(this%number_fields)%set(fe_function, field_id, name)
    end subroutine output_handler_base_add_fe_function


    subroutine output_handler_base_fill_data(this)
    !-----------------------------------------------------------------
    !< Attach a fe_space to the output_handler_base_t derived type
    !-----------------------------------------------------------------
        class(output_handler_base_t),     intent(inout) :: this
        type(fe_iterator_t)                             :: fe_iterator
        type(fe_accessor_t)                             :: fe
        type(output_handler_cell_fe_function_t)         :: output_handler_cell_function
        type(output_handler_patch_t)                    :: patch
        type(output_handler_patch_subcell_iterator_t)   :: subcell_iterator
    !-----------------------------------------------------------------
        assert(associated(this%fe_space))

        ! Create FE iterator 
        fe_iterator             = this%fe_space%create_fe_iterator()

        ! Allocate VTK geometry and connectivity data
!        call this%allocate_elemental_arrays()
!        call this%allocate_nodal_arrays()
!        call this%initialize_coordinates()

        ! Create Output Cell Handler and allocate patch fields
        call output_handler_cell_function%create(this%fe_space)
        call patch%create(this%number_fields)
        ! Translate coordinates and connectivities to VTK format for every subcell
        do while ( .not. fe_iterator%has_finished())
            ! Get Finite element
            call fe_iterator%current(fe)
            if ( fe%is_local() ) then
                call output_handler_cell_function%build_patch(fe, this%number_fields, this%fe_fields(1:this%number_fields), patch)
                subcell_iterator = patch%get_subcells_iterator()
!               ! Fill data
                do while(.not. subcell_iterator%has_finished())
!                    call subcell_iterator%get_coordinates(coordinates)
!                    call subcell_iterator%get_connectivity(connectivity)
!                    call subcell_iterator%get_field(1, field)
!                   this%append_cell(SUBCELL)
                    call subcell_iterator%next()
                enddo
            endif
            call fe_iterator%next()
        end do

        call patch%free()
        call output_handler_cell_function%free()
        call fe_iterator%free()
        call fe%free()
    end subroutine output_handler_base_fill_data

end module output_handler_base_names

