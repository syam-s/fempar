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
module par_matrix_vector
  ! Serial modules
  use fem_vector_names
  
  ! Parallel modules
  use par_matrix_names
  use par_vector_names
  use par_context_names
  
  implicit none
# include "debug.i90"

  private

  public :: par_matvec, par_matvec_trans

contains

  subroutine par_matvec(a,x,y)
    implicit none
    ! Parameters
    type(par_matrix) , intent(in)    :: a
    type(par_vector) , intent(in)    :: x
    type(par_vector) , intent(inout) :: y
    ! Locals
    !integer(c_int)                   :: ierrc
    real :: aux

    ! This routine requires the partition/context info
    assert ( associated(a%p_env) )
    assert ( associated(a%p_env%p_context) )

    assert ( a%p_env%p_context%created .eqv. .true.)
    if(a%p_env%p_context%iam<0) return

    assert ( associated(x%p_env) )
    assert ( associated(x%p_env%p_context) )

    assert ( associated(y%p_env) )
    assert ( associated(y%p_env%p_context) )
    
    assert (x%state == full_summed) 
    ! write (*,*) 'MVAX'
    ! call fem_vector_print ( 6, x%f_vector )
    ! write (*,*) 'MVAY'
    ! call fem_vector_print ( 6, y%f_vector )
    call fem_matvec (a%f_matrix, x%f_vector, y%f_vector) 
    ! write (*,*) 'MVD'
    ! call fem_vector_print ( 6, y%f_vector )
    y%state = part_summed
  end subroutine par_matvec

  subroutine par_matvec_trans(a,x,y)
    implicit none
    ! Parameters
    type(par_matrix) , intent(in)    :: a
    type(par_vector) , intent(in)    :: x
    type(par_vector) , intent(inout) :: y
    ! Locals
    !integer(c_int)                   :: ierrc
	
    ! This routine requires the partition/context info
    assert ( associated(a%p_env) )
    assert ( associated(a%p_env%p_context) )

    assert ( associated(x%p_env) )
    assert ( associated(x%p_env%p_context) )

    assert ( associated(y%p_env) )
    assert ( associated(y%p_env%p_context) )
    
    assert (x%state == full_summed) 
    call fem_matvec_trans (a%f_matrix, x%f_vector, y%f_vector) 
    y%state = part_summed
  end subroutine par_matvec_trans

end module par_matrix_vector
