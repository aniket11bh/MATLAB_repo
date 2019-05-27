% Implement a simple strategy to populate stars only with one mothership

% 1. Find closest star of MS for a 0.5 mn tof for which the rendezvous deltaV < 300 km/s
% 2. do loop
%     For each settled star, go forward 2 mn yrs and find three closest stars for each Settler ship, such that initial deltaV transfer is <175 kmps and rendezvous deltaV is <175 kmps
%     while t<90 myr
% 3. Find the settlement tree

clc
clear all
close all

%% Load data
load star_snapshots
load star_data
load J_store

global star_data  R_vec phi_vec omega_vec i_vec theta_f
global v_vec n_vec
global J_merit delV_max delV_used
global R_min R_max

%Constants
kpc2km = 30856775814671900;
myr = 1e6*31557600;
kms2kpcpmyr = myr/kpc2km;
kpcpmyr2kms = kpc2km / myr;
dtr = pi/180;
R_min = 2;
R_max = 32;

% Update star database variables
R_vec = data(:,2); % kpc (kiloparsecs)
phi_vec = data(:,5); % phi (deg)
omega_vec = data(:,4); % omega (deg)
i_vec = data(:,3); % i (deg)
theta_f= data(:,6); % final polar angle (deg)
k = [0.00287729 0.0023821 -0.0010625 0.000198502 -1.88428e-05 9.70521e-07 -2.70559e-08 3.7516e-10 -1.94316e-12];
v_vec = kms2kpcpmyr*([R_vec.^0 R_vec.^1 R_vec.^2 R_vec.^3 R_vec.^4 R_vec.^5 R_vec.^6 R_vec.^7 R_vec.^8]*k').^-1; % Star speeds kpc/Myr
n_vec = (1/dtr)*(v_vec ./ R_vec); % (deg/mYR)

star_data = data; % Load the star IDs into this variable
star_ID   = zeros(100,1e5); % Assuming 100 generations of settlements amd 100000 stars to be potentially covered

J_merit =0;
delV_max = 0;
delV_used = 0;

fileID = fopen('strategy2.txt','w');
fprintf(fileID,'%s\n','strategy2');

settlement_tree_sp=[];
settlement_tree_ms=[];

% Outputs
% analysis of dV vs tof. starting from Sol, find and transfer to the closest
% star at each snap

%% Mother ship capture of near star with minimum transfer deltaV
% Initialize sol state
for mothership_id=-1:-1:-3
    
    J_store=unique(J_store,'rows');
    J_store=sortrows(J_store,6,'descend');
    
    t_departure=J_store(2-mothership_id,2);     %myr according to CB's analysis for min deltaV
    i_departure=t_departure/0.5+1;              %column number query
    t_arrival= J_store(2-mothership_id,4);      %myr
    i_arrival=t_arrival/0.5+1;                  %column index corresponding to t = 6myr
    tof= t_arrival-t_departure;                 %myr
    x0 = [x(1,i_departure) y(1,i_departure) z(1,i_departure) vx(1,i_departure) vy(1,i_departure) vz(1,i_departure)]';  % Sol position at t0
    r0 = x0(1:3);
    v0_guess = x0(4:6); % Guess initial condition for solver
    
    num_impulses_ms=0;
    sum_impulses_ms=0;
    store_results =zeros(1,16);
    delv_store=[];
    state_store=[];
    
    J_merit_temp =0;
    delV_max_temp =0;
    delV_used_temp =0;
    
    tic
    
    constraints_met=0; % check whether delta V constraints are met after finding a solution
    %%
    
    while constraints_met==0
        
        % Sol-less data
        star_positions_target=[x(2:end,i_arrival),y(2:end,i_arrival),z(2:end,i_arrival)]; % Except sun, all position values for stars at t=tof
        star_velocities_target=[vx(2:end,i_arrival),vy(2:end,i_arrival),vz(2:end,i_arrival)]; % Except sun, all position values for stars at t=tof
        
        idx = J_store(2-mothership_id,1);
        x_t = [x(idx+1,i_arrival) y(idx+1,i_arrival) z(idx+1,i_arrival) vx(idx+1,i_arrival) vy(idx+1,i_arrival) vz(idx+1,i_arrival)]'; % Target states
        
        vt = x_t(4:6);
        rt = x_t(1:3);
        
        [states,v0,vf]= shooting_solver(r0,rt,tof,v0_guess);
        
        store_results = [x_t(1:6)' states(1,4:6) states(end, 4:6) x_t(4:6)'  tof];
        
        delv_transfer= norm(v0-v0_guess');
        delv1= v0-v0_guess';
        delv_rendezvous= vecnorm((store_results(:,10:12)-store_results(:,13:15))')';
        delv2= (-store_results(:,10:12)+store_results(:,13:15)); % rendezvous delv
        
        %% Check  whether it is worth selecting the star with respect to the
        % merit function increase
        delV_max_temp = delV_max + 300; % Add the mothership dv_limits (km/s)
        delV_used_temp = delV_used + delv_transfer * kpcpmyr2kms + delv_rendezvous * kpcpmyr2kms; % Add the mothership dv_limits (km/s)
        star_ID_temp = [star_ID(star_ID~=0) ; idx];
        error_J_term_temp = J_N_r_theta(star_ID_temp,star_data);
        J_merit_temp = error_J_term_temp * delV_max_temp / delV_used_temp;
        
        %% Identify successful or failed transfer
        if delv_transfer * kpcpmyr2kms > 200 || delv_rendezvous * kpcpmyr2kms > 300   % If Mothership initial impulse exceeds  200 km/s or setlling pod impulse exceeds 300 km/s
            disp(['no solution at tof (myr):' num2str(tof)])
            tof =tof+0.5;
            t_arrival= t_departure+tof;                 %myr
            i_arrival=t_arrival/0.5+1;                          %column index corresponding to t = 6myr
            
            if t_arrival>89.5
                break
            end
        else
            
            % Successful transfer
            delV_used = delV_used + delv_transfer * kpcpmyr2kms + delv_rendezvous * kpcpmyr2kms; % km/s
            delV_max = delV_max + 300; % km/s
            
            % Update mothership impulses
            num_impulses_ms=num_impulses_ms+1;
            sum_impulses_ms=sum_impulses_ms+delv_transfer;
            
            if num_impulses_ms>3 || sum_impulses_ms * kpcpmyr2kms > 500 % Dont use more than three impulses or more than 500 kmps dV
                % Generation 0 mothership star captures and update the star
                % settled data base
                %             star_database_ms = find_solution_intercepts_ms(t_departure,r0,v0_guess,idx_prev);
                break
            elseif num_impulses_ms==1
                % Update settled star ids
                star_ID(1,num_impulses_ms) = idx; % 1st settlement from Mothership
                delV_max = delV_max + 500; % Add the mothership dv_limits (km/s)
                error_J_term = J_N_r_theta(star_ID(star_ID~=0),star_data);
                J_merit = error_J_term * delV_max / delV_used;
                constraints_met=1;
            else
                % Update settled star ids
                star_ID(1,num_impulses_ms) = idx; % 1st settlement from Mothership
                error_J_term = J_N_r_theta(star_ID(star_ID~=0),star_data);
                J_merit = error_J_term * delV_max / delV_used;
            end
            
            delv_store = [delv_store; delv1 delv_transfer delv2 delv_rendezvous t_departure t_arrival];
            state_store = [state_store; states];
            settlement_tree_sp =[settlement_tree_sp; mothership_id 1 idx t_arrival delv2* kpcpmyr2kms];
        end
        
    end
    % Mothership line
    settlement_tree_ms=[settlement_tree_ms; mothership_id, 0, 1, 1, t_departure, delv1 * kpcpmyr2kms];
    fprintf(fileID,['\n' repmat('%d,',1,4) repmat('%0.12f,',1,4)],settlement_tree_ms(end,:)');
    % Settlement Pod line
    fprintf(fileID,['\n' repmat('%0.0f,',1, 3) repmat('%0.12f,',1,4)],settlement_tree_sp(end,:)');
end

toc;
toc-tic

% Fastship line
star_ID(1,4:5) = [76457 45078];
settlement_tree_fs(1:2,:)=[-11,76457,8,61,9.82419017275941,-12.2229794464399,-0.758833716987316,-7.05705080167052,12.9841046519746,-0.931972851585255;
                           -12,45078,4,54.5000000000000,12.2216484308859,-8.67292111974953,1.16938984963069,-8.83079622405303,8.81443650509784,-1.20819512866258];
fprintf(fileID,['\n' repmat('%0.0f,',1,2) repmat('%0.12f,',1,8)],settlement_tree_fs');


%% Greedy strategy for settlement
% For departure time of 8 (6+2) myr, identify the three closest stars
% positionally and make a Gen 1 set of settler ships

gen = 1; % 1st generation of settler ships to be seen
settlement_tree_ss=[];

while(gen<5)
    
    % remove the stars that are already occupied for generating the search
    % space
    disp(['Current gen:' num2str(gen+1)])
    
    idx_search = star_data(2:end,1);       % Complete search space for stars except sol
    star_id_settled = star_ID(star_ID~=0); % IDs for settled stars
    % idx_search = setdiff(idx_search,star_id_settled); % Remove settled star IDs from search space
    
    % Set of upto 3 ^ k stars at Gen k, find 3 closest star for each settled
    % star of Gen k such that upto 3 ^ (k+1) stars selected.
    stars_gen_k = star_ID(gen,:);
    stars_gen_k = stars_gen_k(stars_gen_k~=0); % find the latest generation settled stars
    %r_temp = star_positions_target;
    
    % Search star pairs for all stars in the gen k
    for  j =1 : length(stars_gen_k)
        
        tof = 2.5; % starting with small guess
        ID_jk = stars_gen_k(j); % star ID of the jth element of the kth gen
        
        if gen==1
            
            t_departure=settlement_tree_sp(j,4)+2;    % 2 yr
            t_arrival= t_departure+tof;               % myr
            i_arrival = t_arrival/0.5 +1;             % position history column corresponding to the arrival time
            i_departure = t_departure/0.5+1;          % position history column corresponding to the departure time
            star_positions_target=[x(2:end,i_arrival),y(2:end,i_arrival),z(2:end,i_arrival)]; % Except sun, all position values for stars at t=tof
        else
            
            indx_current_star = find(settlement_tree_ss(:,2) == ID_jk);
            t_departure=settlement_tree_ss(indx_current_star,5)+2; % 2 yr
            t_arrival= t_departure+tof;                 %myr
            i_arrival = t_arrival/0.5 +1;             % position history column corresponding to the arrival time
            i_departure = t_departure/0.5+1;          % position history column corresponding to the departure time
            
            if t_arrival>89.5
                break
            end
            
            star_positions_target=[x(2:end,i_arrival),y(2:end,i_arrival),z(2:end,i_arrival)]; % Except sun, all position values for stars at t=tof
        end
        
        
        idx_jk = find(ID_jk == star_data(:,1)); % find the row number for the ID in the star database
        r0_jk = [x(idx_jk,i_departure) y(idx_jk,i_departure) z(idx_jk,i_departure)];   % Position of the star ID of the jth element of the kth gen at departure time
        v0_jk = [vx(idx_jk,i_departure) vy(idx_jk,i_departure) vz(idx_jk,i_departure)];   % Position of the star ID of the jth element of the kth gen at departure time
        x0 = [r0_jk';v0_jk'];
        idx_vec = find_closest_momentum_star(star_positions_target,star_velocities_target,x0,3,star_ID) ; % 3 closest stars settlerships
        
        for l =1:3  % Find all the closest 3 stars with respect to jth settled star of kth generation
            
            t_arrival_temp=t_arrival;
            t_departure_temp=t_departure;
            i_arrival_temp = t_arrival_temp/0.5 +1;             % position history column corresponding to the arrival time
            i_departure_temp = t_departure_temp/0.5+1;          % position history column corresponding to the departure time
            
            constraints_met =0;
            num_constraint_violation =0;
            
            J_merit_temp =0;
            delV_max_temp =0;
            delV_used_temp =0;
            
            while constraints_met == 0
                idx = idx_vec(l);
                x_t = [x(idx+1,i_arrival_temp) y(idx+1,i_arrival_temp) z(idx+1,i_arrival_temp) vx(idx+1,i_arrival_temp) vy(idx+1,i_arrival_temp) vz(idx+1,i_arrival_temp)]'; % Target states
                
                % Solve the shooting problem for all star pairs and remove the pairs which
                % are problematic in terms of transfer deltaV, rendezvous deltaV,  tof =inf
                tof = t_arrival_temp-t_departure_temp;
                r0 = r0_jk';
                rt = x_t(1:3);
                vt = x_t(4:6);
                v0_guess = [vx(idx_jk,i_departure_temp) vy(idx_jk,i_departure_temp) vz(idx_jk,i_departure_temp)]'; % guess value provided as the star velocity itself
                
                [states,v0,vf]= shooting_solver(r0,rt,tof,v0_guess);
                
                dv1= v0-v0_guess'; % transfer impulse
                delv_transfer = norm(dv1);
                dv2= -vf+vt';      % rendezvous impulse
                delv_rendezvous = norm(dv2);
                
                % Check  whether it is worth selecting the star with respect to the
                % merit function increase
                delV_max_temp = delV_max + 400; % Add the mothership dv_limits (km/s)
                delV_used_temp = delV_used + delv_transfer * kpcpmyr2kms + delv_rendezvous * kpcpmyr2kms; % Add the mothership dv_limits (km/s)
                star_ID_temp = [star_ID(star_ID~=0) ; idx];
                error_J_term_temp = J_N_r_theta(star_ID_temp,star_data);
                J_merit_temp = error_J_term_temp * delV_max_temp / delV_used_temp;
                
                
                if norm(dv1) * kpcpmyr2kms > 175 || norm(dv2) * kpcpmyr2kms > 175 || J_merit_temp -J_merit <0 % no solution
                    %                 disp(['no solution at tof (myr):' num2str(tof)])
                    tof =tof+0.5;
                    t_arrival_temp= t_arrival_temp+0.5;                 %myr
                    i_arrival_temp=t_arrival_temp/0.5+1;                          %column index corresponding to t = 6myr
                    num_constraint_violation = num_constraint_violation+1;
                    
                    if num_constraint_violation> 40 || t_arrival_temp>89.5
                        break
                    end
                    
                else
                    
                    % Successful transfer
                    delV_used = delV_used + delv_transfer * kpcpmyr2kms + delv_rendezvous * kpcpmyr2kms; % km/s
                    delV_max = delV_max + 400; % km/s
                    error_J_term = J_N_r_theta(star_ID(star_ID~=0),star_data);
                    J_merit = error_J_term * delV_max / delV_used;
                    
                    star_ID(gen+1,(j-1)*3+l)=star_data(idx+1,1);
                    % Settlement Pod line
                    % Write the actions in the txt solution file.
                    settlement_tree_ss=[settlement_tree_ss; ID_jk idx 2 t_departure_temp t_arrival_temp dv1* kpcpmyr2kms dv2* kpcpmyr2kms];
                    fprintf(fileID,['\n' repmat('%0.0f,', 1, 3) repmat('%0.12f,', 1, 8) ],settlement_tree_ss(end,:));
                    break
                    
                end
                
            end
        end
    end
    
    % Update the departure and arrival times, generation gen
    gen = gen+1;     % next generation of settler ships to be seen
    
end

% plot star positions versus generation
for i = 1:9
    for j=1:3^(i-1)
        i_f=90/0.5+1;
        if star_ID(i,j)==0
        else
            temp = find(star_ID(i,j) == star_data(:,1)); % find the row number for the ID in the star database
            idx_ij =  star_data(temp,1);
            x_t = [x(idx_ij,i_f) y(idx_ij,i_f) z(idx_ij,i_f) vx(idx_ij,i_f) vy(idx_ij,i_f) vz(idx_ij,i_f)]'; % Target states
            figure(1)
            hold on
            plot3(x_t(1),x_t(2),x_t(3),'*')
        end
        
    end
    
end
