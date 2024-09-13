import SwiftUI
import _PhotosUI_SwiftUI

final class OnboardingViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var age: Double = 50
    @Published var gender: String = "男性"
    @Published var preferences: [String] = []
    @Published var imageSelection:PhotosPickerItem? = nil
    @Published var profileImage:UIImage? = nil
    
    
    
    @Published var alertTitle: String = ""
    @Published var showAlert: Bool = false
    
    @Published var showFields:Bool = false
    @Published var isLoading:Bool = false
    @Published var progress:Double = 0.0
    
    func showAlertTitle(title: String) {
        self.alertTitle = title
        showAlert.toggle()
    }
}

//SignIn with google
extension OnboardingViewModel{
    
    
    func signInWithGoogle() async throws {
        await MainActor.run {
            isLoading = true
            progress = 0.0
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
                progress = 1.0
            }
        }
        
        do {
            let helper = SignInGoogleHelper()
            await updateProgress(0.2)
            
            let tokens = try await helper.signIn()
            await updateProgress(0.4)
            
            let authDataResult = try await AuthenticationManager.shared.signInWithGoogle(tokens: tokens)
            await updateProgress(0.6)
            
            // Check if the user is new
            let isNewUser = !(try await UserManager.shared.checkIfUserExistInDatabase(userId: authDataResult.uid))
            await updateProgress(0.8)
            
            await MainActor.run {
                if isNewUser {
                    self.showFields = true
                } else {
                    self.showFields = false
                }
            }
            
            await updateProgress(1.0)
        } catch {
            await MainActor.run {
                // Handle error, maybe show an alert
                self.alertTitle = "サインインに失敗しました"
                self.showAlert = true
            }
            throw error
        }
    }
    
    func saveUserInputs() async {
        await MainActor.run {
            isLoading = true
            progress = 0.0
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
                progress = 1.0
            }
        }
        
        guard let authDataResult = try? AuthenticationManager.shared.getAuthenticatedUser() else {
            print("OnBoardingView/saveUserInput:Can't get authdatResult")
            return
        }
        
        guard let profileImage = self.profileImage else {
            print("BoardingView/signInWithGoogle:NO photo")
            return
        }
        
        do {
            // Save image
            await updateProgress(0.2)
            let photoURL = try await UserManager.shared.saveImageInStorage(image: profileImage, userId: authDataResult.uid)
            await updateProgress(0.6)
//            let photoURL = try await UserManager.shared.saveImageInStorage(image: profileImage, userId: authDataResult.uid){ percentCompleted in
//                await updateProgress(0.6)
//            }

            let newUser = DBUser(
                authDataResult: authDataResult,
                photoUrl: photoURL,
                preferences: preferences,
                name: name,
                age: age
            )
            
            // Save user data
            await updateProgress(0.8)
            await UserManager.shared.storeNewUser(user: newUser)
            await updateProgress(1.0)
        } catch {
            print("Error saving user data: \(error)")
            // Handle the error appropriately
        }
    }
    
    @MainActor
    private func updateProgress(_ newProgress: Double) {
        progress = newProgress
    }
}
//load the Image func
extension OnboardingViewModel {
    func loadTransferableImage() {
        guard let imageSelection else { return }
        
        Task {
            do {
                let transferableImage = try await imageSelection.loadTransferable(type: TransferableImage.self)
                await MainActor.run {
                    self.profileImage = transferableImage?.image

                }
            } catch {
                print("Failed to load transferable image: \(error)")
            }
        }
    }
}


struct OnboardingView: View {
    @State var onboardingState: Int = 0
    let transition: AnyTransition = .asymmetric(
        insertion: .move(edge: .trailing),
        removal: .move(edge: .leading))
    @StateObject var vm = OnboardingViewModel()
    @Binding var isUserCurrentlyLoggedOut : Bool
    
    let interests = [
        "スポーツ", "音楽", "映画", "読書", "料理", "旅行", "ゲーム", "アート",
        "写真撮影", "フィットネス", "ヨガ", "ダンス", "ハイキング", "キャンプ", "ガーデニング",
        "釣り", "ボランティア活動", "登山", "自転車", "ボードゲーム", "アニメ", "マンガ",
        "瞑想", "書道", "手芸", "ドローン", "カフェ巡り", "DIY", "サイクリング", "プログラミング",
        "言語学習", "ペットの世話"
    ]
    var body: some View {
            
            ZStack {
                Color.customBlack.ignoresSafeArea()
                ZStack {
                    switch onboardingState {
                    case 0:
                        welcomeSection
                            .transition(transition)
                    case 1:
                        addNameSection
                            .transition(transition)
                    case 2:
                        addAgeSection
                            .transition(transition)
                    case 3:
                        addGenderSection
                            .transition(transition)
                    case 4:
                        userInterestsSection
                            .transition(transition)
                    default:
                        RoundedRectangle(cornerRadius: 25.0)
                            .foregroundColor(.green)
                    }
                }
                VStack {
                    Spacer()
                    bottomButton
                }
                .padding(30)
                
                   if vm.isLoading {
                       Color.black.opacity(0.5).ignoresSafeArea()
                       VStack {
                           ProgressView()
                               .progressViewStyle(CircularProgressViewStyle(tint: .white))
                               .scaleEffect(2)
                           
                           ProgressView(value: vm.progress)
                               .frame(width: 200)
                               .tint(.white)
                               .padding()
                           
                           Text("\(Int(vm.progress * 100))%")
                               .foregroundColor(.white)
                               .font(.headline)
                       }
                   }
            }
        
            .alert(isPresented: $vm.showAlert) {
                Alert(title: Text(vm.alertTitle))
                
            }

        }
 }

extension OnboardingView {
    private var bottomButton: some View {
        Text(onboardingState == 0 ? "サインアップ" :
             onboardingState == 4 ? "完了" :
             "次へ")
            .font(.headline)
            .foregroundColor(Color(.customWhite))
            .frame(height: 55)
            .frame(maxWidth: .infinity)
            .background(Color.customOrange)
            .cornerRadius(10)
            .onTapGesture {
                withAnimation(.easeInOut) {
                    handleNextButtonPressed()
                }
            }
            .shadow(color: Color.customOrange, radius: 10)
    }
    
    private var welcomeSection: some View {
        VStack(spacing: 40) {
            Spacer()
            Text("チャットを始めましょう")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundColor(Color.customWhite)
                .overlay(
                    Capsule(style: .continuous)
                        .frame(height: 3)
                        .offset(y: 5)
                        .foregroundColor(.white),
                    alignment: .bottom
                )
            Text("これはオンラインマッチングのための人気No.1アプリです...")
                .fontWeight(.medium)
                .foregroundColor(Color.customWhite)
            Spacer()
            Spacer()
        }
        .multilineTextAlignment(.center)
        .padding(30)
    }
    
    private var addNameSection: some View {
        VStack(spacing: 20) {
            ImagePickerView
                .onAppear{
                    Task{
                        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                    }
                }
                .onChange(of: vm.imageSelection) {
                    vm.loadTransferableImage()
                }
            Text("あなたの名前は？")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundColor(Color.customWhite)
            
            TextField("ここに名前を入力...", text: $vm.name)
                .font(.headline)
                .frame(height: 55)
                .padding(.horizontal)
                .background(.white)
                .cornerRadius(10)
            Spacer()
            Spacer()
        }.padding(30)
    }
    
    private var ImagePickerView : some View{
        VStack{
            PhotosPicker(selection: $vm.imageSelection,matching: .images) {
                VStack{
                    if let image = vm.profileImage{
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(Circle())
                            .frame(width: 128, height: 128)
                        
                    }else{
                        VStack{
                            Image(.profilePic)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .clipShape(.circle)
                                .frame(width: 128,height: 128)
                            Text("プロフィール画像を選択してください")
                                .font(.headline)
                                .foregroundStyle(Color(.red))
                        }
                    }
                    
                }
                .padding(.vertical)
            }
            if vm.imageSelection != nil{
                Button("Remove Image"){
                    vm.imageSelection = nil
                    vm.profileImage = nil
                }
            }
        }
    }
    
    private var addAgeSection: some View {
        VStack(spacing: 40) {
            Spacer()
            Text("あなたの年齢は？")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("\(String(format: "%.0f", vm.age))歳")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Slider(value: $vm.age, in: 18...100, step: 1)
                .accentColor(.white)
            
            Spacer()
            Spacer()
        }
        .multilineTextAlignment(.center)
        .padding(30)
    }
    
    private var addGenderSection: some View {
        VStack(spacing: 40) {
            Spacer()
            Text("あなたの性別は？")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Picker("性別を選択", selection: $vm.gender) {
                Text("男性").tag("男性")
                Text("女性").tag("女性")
                Text("その他").tag("その他")
            }
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .padding()
            .background(Color.customWhite)
            .cornerRadius(10)
            .pickerStyle(.menu)
            .tint(Color.customBlack)
            
            Spacer()
            Spacer()
        }
        .multilineTextAlignment(.center)
        .padding(30)
    }
    
    private var userInterestsSection: some View {
        VStack(spacing: 20) {
            Text("興味のある分野を選択してください")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    ForEach(interests, id: \.self) { interest in
                        InterestButton(title: interest, isSelected: vm.preferences.contains(interest)) {
                            if vm.preferences.contains(interest) {
                                guard let index = vm.preferences.firstIndex(of: interest)else {return}
                                vm.preferences.remove(at: index)
                            } else {
                                vm.preferences.append(interest)
                            }
                        }
                    }
                }
            }
        }
        .padding(30)
        .padding(.bottom,55)
    }
}

struct InterestButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(isSelected ? .white : .customOrange)
                .padding()
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.customOrange : Color.white)
                .cornerRadius(10)
        }
    }
}

extension OnboardingView {
    
    private func handleNextButtonPressed() {
        switch onboardingState {
        case 0:
            Task {
                do {
                    try await vm.signInWithGoogle()
                    if vm.showFields {
                        withAnimation(.spring()) {
                            onboardingState += 1
                        }
                    }else{
                        self.isUserCurrentlyLoggedOut = false
                    }
                } catch {
                    print("Error signing in with Google: \(error)")
                }
            }
        case 1:
            guard vm.name.count > 2 else{
                vm.showAlertTitle(title: "名前は３文字以上入力してください！！")
                return
            }
            guard vm.imageSelection != nil else{
                vm.showAlertTitle(title: "プロフィール写真を選択してください！！")
                return
            }
            withAnimation(.spring()) {
                onboardingState += 1
            }
        case 4:
            guard !vm.preferences.isEmpty else {
                vm.showAlertTitle(title: "少なくとも1つの興味を選択してください！")
                return
            }
            
            Task {
                await vm.saveUserInputs()
                await MainActor.run {
                    self.isUserCurrentlyLoggedOut = false
                }
            }
        default:
            withAnimation(.spring()) {
                onboardingState += 1
            }
        }
    }
}

#Preview {
    OnboardingView(isUserCurrentlyLoggedOut: .constant(true))
}
