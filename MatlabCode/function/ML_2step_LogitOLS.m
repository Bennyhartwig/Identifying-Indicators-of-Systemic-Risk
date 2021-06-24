function [output] = ML_2step_LogitOLS(y1,x1,y2,x2,pMIN,pMAX,startIND,endIND)


%%
% input parmaters
% - y1 dummy variable (Tfull x 1)
% - x1 regressors (Tfull x k1)

% - y2 continuous variable (Tfull x 1)
% - x2 control regressors (Tfull x k2)
% - pMIN  minimum lag (can be contemporenous)
% - pMAX  maximum lags of  pred. prob)

% - startIND (start index of regression)
% - endIND (end index of regression)



%% Define function
logitlink = @(X,beta) exp(X*beta)./(1+exp(X*beta));

% effective vector length
Y1 = y1(startIND:endIND);
Y2 = y2(startIND:endIND);
X1 = x1(startIND:endIND,:);
X2 = x2(startIND:endIND,:);

% determine some parameters
K1 = size(X1,2);
m = size(X2,2);
K2 = m + (pMAX-pMIN) +1;
T = length(Y1);
Tfull = length(y1);

NaNFillY = NaN(startIND-1,1);
NaNFillX1 = NaN(startIND-1,K1);
NaNFillX2 = NaN(startIND-1,m );
NaNFillZ = NaN(startIND-1,(pMAX-pMIN)+1 );


% 1st Stage: Logit regression
% introduced new stopping criterion (allow for perfect fit)

result = logit(Y1,X1); 
theta1 = result.beta;
sig21 = result.sige;


% startIND_ =max([ sum(isnan(y1),1) sum(isnan(x1),1)])+1;
%                 % check for all 1's or all 0's
% tmp = find(y1(startIND_:end) ==1);
% chk = length(tmp);
% [nobs junk] = size(y1(startIND_:end));
%  % make NaN regression: 
%  if startIND_ > endIND; b=nan(size(x1,2),1);  stats.resid=nan(size(x1,1),1) ;  % when there is no value for the indicator
%  elseif chk == nobs || chk == 0;  b=nan(size(X1,2),1); stats.resid=nan(size(X1,1),1) ;  % when there is no crises in the sample
%  else
% % works even when there is perfect fit
% [b, ~, stats] = glmfit(X1,Y1,'binomial','link','logit','constant','off'); %Commented in YSS 19.10.20
%  end
% theta1 = b;
% sig21 = (stats.resid'*stats.resid)/length(stats.resid);
% 
% 

y1hat = logitlink(x1,theta1); Y1hat = y1hat(startIND:endIND); % compute predicted probability
z = [lagmatrix(y1hat,pMIN:pMAX)]; % generate predicted regressors
U1 = (Y1-Y1hat);

if ~isnan(Y1hat) == 1 % check failure of first stage regression
    
    % effective vector length
    Z = z(startIND:endIND,:);
    
    % 2nd Stage: linear regression (ML estimates)
    bigX2 = [X2 Z];
    theta2 = (bigX2'*bigX2)^-1*bigX2'*Y2;
    beta = theta2(1:m); gamma = theta2(m+1:end);
    Y2hat = bigX2*theta2;
    U2 = (Y2-Y2hat);
    
    sig22 = sum(U2.^2)/T;
    lik2 = -T/2*log(2*pi)-T/2*log(sig22) -(U2'*U2)/(2*sig22);
    AIC2 = -lik2+1/2*K2; % Akaike IC
    BIC2 = -lik2+1/2*K2*log(T); % BIC IC
    
    
    lagx1 = lagmatrix(x1,[pMIN : pMAX]); lagX1 = lagx1(startIND:endIND,:);
    bigX1 = lagX1.*(kron(Z.*(1-Z),ones(1,K1)))*kron(gamma,speye(K1));
    
    
    
    % Compute first order derivatives
    f1_theta1 =  X1'*sparse(1:T,1:T,U1);
    f2_theta2 =  1/sig22 * bigX2'*sparse(1:T,1:T,U2);
    f2_theta1 = 1/sig22 * bigX1'*sparse(1:T,1:T,U2);
    % Compute second order derivatives
    f1_alpha_alphap = - X1'*sparse(1:T,1:T,(Y1hat.*(1-Y1hat)))*X1;
    f2_theta_thetap = - 1/sig22 * bigX2'*bigX2;
    f2_theta_alphap = - 1/sig22 * bigX2'*bigX1;
    
    
    % Compute expected hessian
    H11 = ( f1_alpha_alphap);
    H22 = ( f2_theta_thetap);
    H21 = ( f2_theta_alphap);

    
   
    % Compute outer product gradient variance
    % Sig11 = - H11 (information matrix equality)
    Sig22 = ( f2_theta2*f2_theta2');
    Sig21 = f2_theta2*f1_theta1';
    Sig12 = f1_theta1*f2_theta2';
    
    
%     % Greene Estimator
%     C = -f2_theta2*f2_theta1'; % estimate for H21 (see Greene)
%     H21 = C;
%     
    % Compute covariance matrix
    H1 = (-H11)^-1; % expected Hessian
    % expected Hessian
    H2 = (-H22)^-1; 
    % corrected  variance-covariance (independence)
    H2Istar = (-H22)^-1*( (-H22)   +H21*(-H11)^-1*H21')*(-H22)^-1;
     % corrected expected Hessian
    H2star = (-H22)^-1*( (-H22)   +H21*(-H11)^-1*H21'    +Sig21*(-H11)^-1*H21'  +H21*(-H11)^-1*Sig12 )*(-H22)^-1;
    
    % robust variance-covariance
    R2 = (-H22)^-1*Sig22*(-H22)^-1; 
    % corrected robust variance-covariance (independence)
    R2Istar = (-H22)^-1*( Sig22 +H21*(-H11)^-1*H21')*(-H22)^-1; % corrected robust variance-covariance under independence
    % corrected robust variance-covariance 
    R2star = (-H22)^-1*( Sig22  +H21*(-H11)^-1*H21'  +Sig21*(-H11)^-1*H21' +H21*(-H11)^-1*Sig12 )*(-H22)^-1; % corrected variance-covariance
    
    % check positive definiteness
    try;    if sum((eig(H2star)<0))>0, H2star = eye(size(H2))*9999^2; end;   end
    try;    if sum(eig(R2star)<0)>0, R2star = eye(size(R2))*9999^2; end;    end
else
    
    
    % effective vector length
    Z = z(startIND:endIND,:);
    
    % 2nd Stage: linear quantile regression (ML estimates)
    bigX2 = [X2 Z];
    theta2 = NaN(K2,1);
    beta = theta2(1:m); gamma = theta2(m+1:end);
    sig22 = NaN;

    Y2hat = bigX2*theta2;
    U2 = Y2- bigX2*theta2;
    
    H1 = NaN(K1);
    H2 = NaN(K2);  H2Istar  =NaN(K2); H2star  =NaN(K2);
    R2 = NaN(K2);  R2Istar  =NaN(K2);R2star  =NaN(K2);
    
    lik2 = NaN; AIC2 = NaN; BIC2 = NaN;
end

%% Save output
output.T = length(y1);
output.nobs = T;

% 1st stage
output.meth1 = 'logit';
output.Y1 =[NaNFillY; Y1];
output.X1 =[NaNFillX1;  X1];
output.Y1hat = [NaNFillY; Y1hat];
output.U1 = [NaNFillY; U1];


output.theta1 = theta1;
output.SIG21 = sig21;

% Inference epxected Hessian
output.H1 = H1;
output.stdH1 = sqrt(diag(H1));
output.tstatH1 = theta1./sqrt(diag(H1));
output.pvalH1 = (1-tcdf(abs(output.tstatH1),T-K1 ))*2  ; % two sided pvalue


output.K1 = K1;
output.lratio1 = result.lratio; %YSS 19.10.
output.pvalLR1 = result.pval;
output.lik1 = result.lik;
output.AIC1 = result.AIC;
output.BIC1 = result.BIC;


%compute manually
% [t k] = size(X1);
% tmp = find(Y1 ==1);
% P = length(tmp);
% cnt0 = t-P;
% cnt1 = P;
% P = P/t; % proportion of 1's
% like0 = t*(P*log(P) + (1-P)*log(1-P)); % restricted likelihood
% like1 = lo_like(b,Y1,X1); % unrestricted Likelihood
%  output.lratio1 = 2*(like1-like0); % LR-ratio test against intercept model
%  output.pvalLR1 = 1-chi2cdf(output.lratio1,k-1); % p-value of LR-ratio test against intercept model
%  output.lik1 = like1;% unrestricted Likelihood
%  output.AIC1 = -like1+1/2*k; % Akaike IC
%  output.BIC1 = -like1+1/2*k*log(t); % BIC IC

% 2nd stage
output.meth2 = 'OLS';
output.Y2 = [NaNFillY; Y2];
output.X2 = [NaNFillX2; X2];
output.Z = [NaNFillZ ;Z];
output.Y2hat = [NaNFillY; Y2hat];
output.U2 = [NaNFillY; U2];


output.theta = theta2;
output.beta = beta;
output.gamma = gamma;
output.SIG22 = sig22;

% Inference expected Hessian
output.H2 = H2;
output.stdH2 = sqrt(diag(H2));
output.tstatH2 = theta2./sqrt(diag(H2));
output.pvalH2 =  (1-tcdf(abs(output.tstatH2),T-K2 ) )*2 ; % two sided pvalue

% Inference corrected expected Hessian (independence)
output.H2Istar = H2Istar;
output.stdH2Istar= sqrt(diag(H2Istar));
output.tstatH2Istar= theta2./sqrt(diag(H2Istar));
output.pvalH2Istar =  (1-tcdf(abs(output.tstatH2Istar),T-K2 ) )*2 ; % two sided pvalue

% Inference corrected expected Hessian
output.H2star = H2star;
output.stdH2star = sqrt(diag(H2star));
output.tstatH2star = theta2./sqrt(diag(H2star));
output.pvalH2star =  (1-tcdf(abs(output.tstatH2star),T-K2 ) )*2 ; % two sided pvalue


% Inference Heteroskedasticity Robust (Huber Sandwich)
output.R2 = R2;
output.stdR2 = sqrt(diag(R2));
output.tstatR2 = theta2./sqrt(diag(R2));
output.pvalR2 =  (1-tcdf(abs(output.tstatR2),T-K2  ))*2  ; % two sided pvalue

% Inference corrected Heteroskedasticity Robust (independence) (Huber Sandwich)
output.R2Istar = R2Istar;
output.stdR2Istar = sqrt(diag(R2Istar));
output.tstatR2Istar = theta2./sqrt(diag(R2Istar));
output.pvalR2Istar =  (1-tcdf(abs(output.tstatR2Istar),T-K2  ))*2  ; % two sided pvalue

% Inference corrected Heteroskedasticity Robust (Huber Sandwich)
output.R2star = R2star;
output.stdR2star = sqrt(diag(R2star));
output.tstatR2star = theta2./sqrt(diag(R2star));
output.pvalR2star =  (1-tcdf(abs(output.tstatR2star),T-K2  ))*2  ; % two sided pvalue



output.K2 = K2;
output.m = m;
output.p = pMAX; % number of predicted probabilities
output.lik2 = lik2;
output.AIC2 = AIC2;
output.BIC2 = BIC2;



