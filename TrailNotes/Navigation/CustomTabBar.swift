import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Tab

    var body: some View {
        HStack {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: selectedTab == tab ? .bold : .regular))
                            .foregroundColor(selectedTab == tab ? AppTheme.accent : AppTheme.secondaryText)
                            .scaleEffect(selectedTab == tab ? 1.1 : 1.0)

                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(selectedTab == tab ? AppTheme.accent : AppTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            AppTheme.cardBackground
                .shadow(color: AppTheme.cardShadow, radius: 8, x: 0, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
