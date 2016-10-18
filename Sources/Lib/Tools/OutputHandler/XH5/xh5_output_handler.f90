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

module xh5_output_handler_names

USE types_names
USE memor_names
USE xh5for
USE environment_names
USE output_handler_base_names
USE output_handler_fe_field_names
USE fe_space_names,             only: serial_fe_space_t
USE output_handler_patch_names, only: patch_subcell_iterator_t


implicit none
#include "debug.i90"
private

    type, extends(output_handler_base_t) :: xh5_output_handler_t
    private 
        type(xh5for_t)            :: xh5
        real(rp),     allocatable :: X(:)
        real(rp),     allocatable :: Y(:)
        real(rp),     allocatable :: Z(:)
        integer(ip),  allocatable :: Connectivities(:)
        integer(ip)               :: node_offset = 0
    contains
        procedure,                 public :: write                          => xh5_output_handler_write
        procedure,                 public :: allocate_cell_and_nodal_arrays => xh5_output_handler_allocate_cell_and_nodal_arrays
        procedure,                 public :: append_cell                    => xh5_output_handler_append_cell
        procedure,                 public :: free                           => xh5_output_handler_free
    end type

public :: xh5_output_handler_t

contains


    subroutine xh5_output_handler_free(this)
    !-----------------------------------------------------------------
    !< Free procedure
    !-----------------------------------------------------------------
        class(xh5_output_handler_t), intent(inout) :: this
    !-----------------------------------------------------------------
        call this%xh5%free()
        if(allocated(this%X))              call memfree(this%X,              __FILE__, __LINE__)
        if(allocated(this%Y))              call memfree(this%Y,              __FILE__, __LINE__)
        if(allocated(this%Z))              call memfree(this%Z,              __FILE__, __LINE__)
        if(allocated(this%Connectivities)) call memfree(this%Connectivities, __FILE__, __LINE__)
    end subroutine xh5_output_handler_free


    subroutine xh5_output_handler_allocate_cell_and_nodal_arrays(this)
    !-----------------------------------------------------------------
    !< Allocate cell and nodal arrays
    !-----------------------------------------------------------------
        class(xh5_output_handler_t), intent(inout) :: this
        integer(ip)                                :: number_nodes
        integer(ip)                                :: number_cells
    !-----------------------------------------------------------------
        assert(.not. allocated(this%X))
        assert(.not. allocated(this%Y))
        assert(.not. allocated(this%Z))
        assert(.not. allocated(this%Connectivities))
        number_nodes = this%get_number_nodes()
        number_cells = this%get_number_cells()
        call memalloc(number_nodes, this%X,              __FILE__, __LINE__)
        call memalloc(number_nodes, this%Y,              __FILE__, __LINE__)
        call memalloc(number_nodes, this%Z,              __FILE__, __LINE__)
        call memalloc(number_nodes, this%Connectivities, __FILE__, __LINE__)
        this%Z = 0_rp
    end subroutine xh5_output_handler_allocate_cell_and_nodal_arrays


    subroutine xh5_output_handler_append_cell(this, subcell_iterator)
    !-----------------------------------------------------------------
    !< Append cell data to global arrays
    !-----------------------------------------------------------------
        class(xh5_output_handler_t), intent(inout) :: this
        type(patch_subcell_iterator_t), intent(in) :: subcell_iterator
        real(rp),    allocatable                   :: Coordinates(:,:)
        integer(ip), allocatable                   :: Connectivity(:)
        type(output_handler_fe_field_t), pointer   :: field
        real(rp),                        pointer   :: Value(:,:)
        integer(ip)                                :: number_vertices
        integer(ip)                                :: number_dimensions
        integer(ip)                                :: number_fields
        integer(ip)                                :: number_components
        integer(ip)                                :: i
    !-----------------------------------------------------------------
        number_vertices   = subcell_iterator%get_number_vertices()
        number_dimensions = subcell_iterator%get_number_dimensions()
        number_fields     = this%get_number_fields()

        call subcell_iterator%get_coordinates(this%X(this%node_offset+1:this%node_offset+number_vertices), &
                                              this%Y(this%node_offset+1:this%node_offset+number_vertices), &
                                              this%Z(this%node_offset+1:this%node_offset+number_vertices))

        this%Connectivities(this%node_offset+1:this%node_offset+number_vertices) = &
                            (/(i, i=this%node_offset, this%node_offset+number_vertices-1)/)

        do i=1, number_fields
            number_components = subcell_iterator%get_number_field_components(i)
            field => this%get_field(i)
            if(.not. field%value_is_allocated()) call field%allocate_value(number_components, this%get_number_nodes())
            Value => field%get_value()
            call subcell_iterator%get_field(i, number_components, Value(1:number_components,this%node_offset+1:this%node_offset+number_vertices))
        enddo
        this%node_offset = this%node_offset + number_vertices

    end subroutine xh5_output_handler_append_cell


    subroutine xh5_output_handler_write(this)
    !-----------------------------------------------------------------
    !< Fill global arrays and Write VTU and PVTU files
    !-----------------------------------------------------------------
        class(xh5_output_handler_t), intent(inout) :: this
        class(serial_fe_space_t),        pointer   :: fe_space
        class(environment_t),            pointer   :: mpi_environment
        type(output_handler_fe_field_t), pointer   :: field
        character(len=:), allocatable              :: path
        character(len=:), allocatable              :: prefix
        real(rp), pointer                          :: Value(:,:)
        integer(ip)                                :: number_fields
        integer(ip)                                :: E_IO, i
        integer(ip)                                :: me, np
    !-----------------------------------------------------------------
        call this%fill_data()

        fe_space          => this%get_fe_space()
        assert(associated(fe_space))
        mpi_environment   => fe_space%get_environment()
        assert(associated(mpi_environment))
        call mpi_environment%info(me, np)

        prefix = 'output'

        call this%xh5%Open(FilePrefix = prefix, &
                      Strategy   = XDMF_STRATEGY_CONTIGUOUS_HYPERSLAB, &
                      Action     = XDMF_ACTION_WRITE)
        call this%xh5%SetGrid(NumberOfNodes=this%get_number_nodes(), &
                              NumberOfElements=this%get_number_cells(), &
                              TopologyType=XDMF_TOPOLOGY_TYPE_QUADRILATERAL, &
                              GeometryType=XDMF_GEOMETRY_TYPE_X_Y_Z)
        call this%xh5%WriteTopology(Connectivities=this%Connectivities)
        call this%xh5%WriteGeometry(X=this%X, Y=this%Y, Z=this%Z)

        do i=1, this%get_number_fields()
            field => this%get_field(i)
            Value => field%get_value()
!            call this%xh5%WriteAttribute(Name=varname=field%get_name(), &
!                                    Type=XDMF_ATTRIBUTE_TYPE_SCALAR, &
!                                    Center=XDMF_ATTRIBUTE_CENTER_NODE , &
!                                    Values=Value)
        enddo

        call this%xh5%Close()
        call this%xh5%Free()

    end subroutine xh5_output_handler_write

end module xh5_output_handler_names
