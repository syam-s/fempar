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
module fem_update_names
  use types_names
  use memor_names
  use fe_space_names
  use fem_vector_names
  use fem_block_vector_names
  use fem_conditions_names
  use analytical_names
  use interpolation_tools_names
  implicit none
# include "debug.i90"
  private

  interface fem_update_solution
     module procedure fem_update_solution_mono, fem_update_solution_block
  end interface fem_update_solution
     

  ! Functions
  public :: fem_update_strong_dirichlet_bcond, fem_update_analytical_bcond, fem_update_solution
 
contains
  
  !==================================================================================================
  subroutine fem_update_strong_dirichlet_bcond( fe_space, fcond )
    !-----------------------------------------------------------------------------------------------!
    !   This subroutine updates Dirichlet boundary conditions in unkno from fem_conditions values.  !
    !-----------------------------------------------------------------------------------------------!
    implicit none
    type(fe_space_t)     , intent(inout) :: fe_space
    type(fem_conditions_t), intent(in)    :: fcond
    ! Locals
    integer(ip) :: ielem, iobje, ivar, inode, l_node, gvar, lobje, prob

    do ielem = 1, fe_space%g_trian%num_elems
       prob = fe_space%finite_elements(ielem)%problem
       do ivar=1, fe_space%dof_handler%problems(prob)%p%nvars
          gvar=fe_space%dof_handler%problems(prob)%p%l2g_var(ivar)
          do iobje = 1,fe_space%finite_elements(ielem)%p_geo_reference_element%nobje
             lobje = fe_space%g_trian%elems(ielem)%objects(iobje)
             do inode = fe_space%finite_elements(ielem)%nodes_object(ivar)%p%p(iobje), &
                  &     fe_space%finite_elements(ielem)%nodes_object(ivar)%p%p(iobje+1)-1 
                l_node = fe_space%finite_elements(ielem)%nodes_object(ivar)%p%l(inode)
                if ( fe_space%finite_elements(ielem)%bc_code(ivar,iobje) /= 0 ) then
                   fe_space%finite_elements(ielem)%unkno(l_node,ivar,1) = fcond%valu(gvar,lobje)
                end if
             end do
          end do
       end do
    end do

  end subroutine fem_update_strong_dirichlet_bcond

  !==================================================================================================
  subroutine fem_update_analytical_bcond(vars_of_unk,case,ctime,fe_space,caset,t)
    !-----------------------------------------------------------------------------------------------!
    !   This subroutine updates Dirichlet boundary conditions in unkno from an analytical solution. !
    !-----------------------------------------------------------------------------------------------!
    implicit none
    integer(ip)          , intent(in)    :: vars_of_unk(:)
    integer(ip)          , intent(in)    :: case
    real(rp)             , intent(in)    :: ctime
    type(fe_space_t)      , intent(inout) :: fe_space
    integer(ip), optional, intent(in)    :: caset,t
    ! Locals
    integer(ip) :: ielem,prob,ndime,iobje,lobje,inode,lnode
    integer(ip) :: nvars,ivar,gvar,gnode,unode,cnt
    real(rp)    :: part(3)
    real(rp), allocatable :: coord(:,:),param(:)

    if(case>0) then

       nvars = size(vars_of_unk,1)
       ndime = fe_space%g_trian%num_dims

       ! Allocate parameters
       if(nvars==1) then
          call memalloc(10,param,__FILE__,__LINE__)
       else
          call memalloc(30,param,__FILE__,__LINE__)
       end if


       do ielem = 1, fe_space%g_trian%num_elems
          prob  = fe_space%finite_elements(ielem)%problem
          gnode = fe_space%finite_elements(ielem)%p_geo_reference_element%nnode
          cnt   = 0

          do ivar=vars_of_unk(1),vars_of_unk(nvars)

             ! Global variable
             cnt = cnt+1
             gvar=fe_space%dof_handler%problems(prob)%p%l2g_var(ivar)

             ! Interpolate coordinates
             unode = fe_space%finite_elements(ielem)%reference_element_vars(ivar)%p%nnode
             call memalloc(ndime,unode,coord,__FILE__,__LINE__)
             call interpolate(ndime,gnode,unode,fe_space%finite_elements(ielem)%inter(ivar)%p, &
                  &           fe_space%g_trian%elems(ielem)%coordinates,coord)

             do iobje = 1,fe_space%finite_elements(ielem)%p_geo_reference_element%nobje
                lobje = fe_space%g_trian%elems(ielem)%objects(iobje)

                if ( fe_space%finite_elements(ielem)%bc_code(ivar,iobje) /= 0 ) then

                   do inode = fe_space%finite_elements(ielem)%nodes_object(ivar)%p%p(iobje), &
                        &     fe_space%finite_elements(ielem)%nodes_object(ivar)%p%p(iobje+1)-1 
                      lnode = fe_space%finite_elements(ielem)%nodes_object(ivar)%p%l(inode)

                      call analytical_field(case,ndime,coord(:,lnode),ctime,param)

                      if(present(caset)) then
                         if(caset>0) then
                            call analytical_field(caset,ndime,coord(:,lnode),ctime,part)
                            if(present(t)) then
                               fe_space%finite_elements(ielem)%unkno(lnode,ivar,1) =  param(cnt)*part(t)
                            else
                               fe_space%finite_elements(ielem)%unkno(lnode,ivar,1) =  param(cnt)*part(1)
                            end if
                         else
                            fe_space%finite_elements(ielem)%unkno(lnode,ivar,1) =  param(cnt)
                         end if
                      else
                         fe_space%finite_elements(ielem)%unkno(lnode,ivar,1) =  param(cnt)
                      end if

                   end do
                end if
             end do

             ! Deallocate auxiliar coordinates
             call memfree(coord,__FILE__,__LINE__)

          end do
       end do

       ! Deallocate params
       call memfree(param,__FILE__,__LINE__)

    end if
    
  end subroutine fem_update_analytical_bcond

  !==================================================================================================
  subroutine fem_update_solution_mono(fevec,fe_space,iblock)
    !-----------------------------------------------------------------------------------------------!
    !   This subroutine stores the solution from a fem_vector into unkno.                           !
    !-----------------------------------------------------------------------------------------------!
    implicit none
    type(fem_vector_t)     , intent(in)    :: fevec   
    type(fe_space_t)      , intent(inout) :: fe_space
    integer(ip), optional, intent(in)    :: iblock
    ! Locals
    integer(ip) :: ielem,iblock_,iprob,nvapb,ivar,lvar,inode,idof

    iblock_ = 1
    if ( present(iblock) ) iblock_ = iblock
    
    ! Loop over elements
    do ielem = 1, fe_space%g_trian%num_elems
       iprob = fe_space%finite_elements(ielem)%problem
       nvapb = fe_space%dof_handler%prob_block(iblock_,iprob)%nd1
       
       ! Loop over problem and block variables
       do ivar = 1, nvapb
          lvar = fe_space%dof_handler%prob_block(iblock_,iprob)%a(ivar)

          ! Loop over elemental nodes
          do inode = 1,fe_space%finite_elements(ielem)%reference_element_vars(lvar)%p%nnode
             idof = fe_space%finite_elements(ielem)%elem2dof(inode,lvar)
             
             if(idof/=0) then

                ! Update unkno
                fe_space%finite_elements(ielem)%unkno(inode,lvar,1) = fevec%b(idof)

             end if

          end do
       end do
    end do
    
  end subroutine fem_update_solution_mono

  !==================================================================================================
  subroutine fem_update_solution_block(blvec,fe_space)
    !-----------------------------------------------------------------------------------------------!
    !   This subroutine stores the solution from a fem_vector into unkno.                           !
    !-----------------------------------------------------------------------------------------------!
    implicit none
    type(fem_block_vector_t), intent(in)    :: blvec   
    type(fe_space_t)       , intent(inout) :: fe_space
    ! Locals
    integer(ip) :: iblock

    ! Loop over blocks
    do iblock = 1,blvec%nblocks
       
       ! Call monolithic update
       call fem_update_solution_mono(blvec%blocks(iblock),fe_space,iblock)

    end do
    
  end subroutine fem_update_solution_block

end module fem_update_names
