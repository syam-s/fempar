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
module lagrangian_fe_conditions_names
  use fempar_names
  
  implicit none
# include "debug.i90"
  private
  type, extends(conditions_t) :: lagrangian_fe_conditions_t
     private
     integer(ip)  :: num_dims
     class(scalar_function_t), pointer :: boundary_function  
   contains
     procedure :: set_boundary_function       => lagrangian_fe_conditions_set_boundary_function
     procedure :: set_number_dimensions       => lagrangian_fe_conditions_set_num_dims     
     procedure :: get_num_components          => lagrangian_fe_conditions_get_num_components  
     procedure :: get_components_code         => lagrangian_fe_conditions_get_components_code
     procedure :: get_function                => lagrangian_fe_conditions_get_function
  end type lagrangian_fe_conditions_t
  
  public :: lagrangian_fe_conditions_t
  
contains

  subroutine lagrangian_fe_conditions_set_boundary_function (this, boundary_function)
    implicit none
    class(lagrangian_fe_conditions_t)     , intent(inout) :: this
    class(scalar_function_t), target, intent(in)    :: boundary_function
    this%boundary_function => boundary_function
  end subroutine lagrangian_fe_conditions_set_boundary_function
  
  subroutine lagrangian_fe_conditions_set_num_dims (this, num_dims)
    implicit none
    class(lagrangian_fe_conditions_t)     , intent(inout) :: this
    integer(ip),                            intent(in)    :: num_dims
    this%num_dims = num_dims
  end subroutine lagrangian_fe_conditions_set_num_dims

  function lagrangian_fe_conditions_get_num_components(this)
    implicit none
    class(lagrangian_fe_conditions_t), intent(in) :: this
    integer(ip) :: lagrangian_fe_conditions_get_num_components
    lagrangian_fe_conditions_get_num_components = 1 + 1 + this%num_dims + this%num_dims**2
  end function lagrangian_fe_conditions_get_num_components

  subroutine lagrangian_fe_conditions_get_components_code(this, boundary_id, components_code)
    implicit none
    class(lagrangian_fe_conditions_t), intent(in)  :: this
    integer(ip)            , intent(in)  :: boundary_id
    logical                , intent(out) :: components_code(:)
    !assert ( size(components_code) == 1 )
    !components_code(1) = .true.
    components_code(1:this%get_num_components()) = .false.
    if ( boundary_id == 1 ) then
      components_code(1:this%get_num_components()) = .true.
    end if
  end subroutine lagrangian_fe_conditions_get_components_code
  
  subroutine lagrangian_fe_conditions_get_function ( this, boundary_id, component_id, function )
    implicit none
    class(lagrangian_fe_conditions_t), target, intent(in)  :: this
    integer(ip)                        , intent(in)  :: boundary_id
    integer(ip)                        , intent(in)  :: component_id
    class(scalar_function_t), pointer  , intent(out) :: function
    assert ( component_id == 1 )
    assert ( associated(this%boundary_function) )
    nullify(function)
    if ( boundary_id == 1 ) then
      function => this%boundary_function
    end if  
  end subroutine lagrangian_fe_conditions_get_function 

end module lagrangian_fe_conditions_names
